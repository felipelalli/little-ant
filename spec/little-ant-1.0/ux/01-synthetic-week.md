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

Before the ordinary week, cold-load a generated JSONL stream with 1,234 valid
events and validate UX-R02: the interactive counter begins at zero, advances
monotonically from the actual fold, reaches `001234`, and clears into the exact
first envelope without a delay floor or random-stream movement. Repeat with a
small stream, redirected output, `TERM=dumb`, cancellation, and one malformed
line. Small input must not be artificially slowed; non-interactive variants
must contain no splash bytes; cancellation must preserve data; and corruption
must end in the typed startup error rather than a false completed count.

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

- the stacked footer is visibly separate from the automatically served `next`
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
- Enter creates exactly one Inbox Raw and asks no classification or metadata
  question;
- the suspended proposal is revalidated after that Raw commit;
- a later recorded `raw_triage` draw renders the Raw without a Brick `#`
  handle and asks the independent-Work question;
- `no` ranks compatible existing destinations using only inspectable dumb
  evidence; `[m]ore matches...` pages that set, `[s]earch...` autocompletes
  across it, and `[c]reate a new group...` opens behavioral discovery without
  asserting that unseen candidates are unsuitable;
- new-group discovery creates no generic Group object and reaches explicit
  list, RawShelf, or independently focusable Work previews;
- selecting `#bg "Buy groceries"` proposes a ListEntry and duplicate review
  without a global `milk` identity;
- open and resolved duplicate cases expose keep/reopen, add or change
  quantity, and distinguishable-separate-item behavior;
- if the Raw is instead materialized as Work, no hidden Nature fallback
  exists: direct factory Nature choices and guided `[?] I don't know` precede
  any compatible Template, and the exact parent and local importance position
  are visible before the Brick is committed.

Do not predetermine how many screens are required. The baseline exists to
discover whether language normalization, target selection, or Nature choice
creates unacceptable form-like friction.

### SCN-FED-002 — Powered-up delta

Reset to the identical fixture revision and random cursor. Start the REPL with:

```text
mode: powered up · by: /bin/claude-fast.sh
```

It must automatically serve the same opening `next` opportunity. Press
`/`, select `/feed`, enter `comprar leite`, and submit it. The Raw commit must
complete before any model-derived proposal. Validate that a later assisted
triage may propose canonical English, the ListEntry disposition,
`#bg "Buy groceries"`, and duplicate interpretation in fewer screens while
using the same canonical envelope/action IDs. Also feed `milk`, `coffee`, and
`bread` separately and exercise one bounded, attributed recent-Raw batch
proposal. `no` must enter UX-T01 for the originally selected Raw without
resolving or penalizing its neighbors. Any proposed Template must expose its
resulting Nature and source, require `[y]es`, `[n]o`, or `[?] I don't know`,
and enter the unchanged dumb flow after `no`. Record every skipped dumb screen
and the provenance of every added default.

### SCN-FED-003 — Article URL

Run the URL flow in dumb REPL first, then replay it powered up. Ordinary Feed
must commit the URL Raw without a route question. Later triage may propose an
`article_reading` Brick; when confirmed it attaches the preserved source
material and enters sibling importance insertion without treating the URL as
completed work.

### SCN-FED-004 — Skill and web/mobile mirror

Only after SCN-FED-001 through SCN-FED-003 are accepted, render their existing
envelopes in the operator skill and web/mobile reference. Validate
almost-literal parity; do not let the skill supply a missing dumb-core path.

### SCN-FED-005 — Nature discovery coverage

Starting from identical pending Raw-to-Work triage, replay the dumb discovery
tree once for each factory Nature leaf. At every split, replay
`[?] I don't know`, verify
the alternate probe and its branch equivalence, then use uncertainty again and
verify that triage remains pending without creating a Brick. At a leaf, verify
the Nature, decisive reason, final confirmation, `no` return to direct choice,
`?` restart from Q0, and Escape return to the previous question. None may lose
the source Raw, create a Brick, record a domain event, or consume a draw.

## Day 2 — Importance and uncertainty

### SCN-IMP-001 — Binary insertion

Place `#wtms "Write the migration specification"` among siblings using
UX-C01. Validate `more important`, `less important`, `*`, and full Brick
labels.

### SCN-IMP-002 — Two skips

Skip one comparison, receive a replay-deterministic sibling one to three
positions away, then skip again. Validate provisional nearby placement,
visible low confidence, and no false equality. In lottery cadence, prove the
first skip redraws UX-O01 immediately without an interstitial and the second
renders UX-O05 without a draw. In `/order`, prove both prompts use the same
comparators but the second skip advances immediately; complete the pass and
validate the UX-O03 count of placements still needing review.

### SCN-IMP-003 — Contradiction

Create recent direct `A > B` and `B > C` judgments, let FOC-042 select the
never-directly-asked `A` versus `C` pair, and validate that UX-O01 exposes no
inferred answer or validation heading while contextual help shows UX-O08.
Confirm `A > C` once and verify one direct edge, stronger path confidence, the
compact receipt, and no sorter mutation beyond the added evidence.

In a fixed replay, answer `C > A` while every path edge remains above the fresh
threshold. Validate UX-O06, no default or skip, absolute evidence times, and a
pending answer that has not yet changed the effective order. Exercise
`changed`: activate `C > A`, retire both earlier path edges only from current
calculation, and preserve all events and the reason. Replay `mistake`: retract
`C > A`, record direct `A > C`, and retain the coherent path. Replay
uncertainty through UX-O07 for each winner, verifying two winner edges,
minimal incompatible retirement, and preservation of the coherent loser edge.
Choose uncertainty again and validate UX-O09: retain every conflicting event,
keep the previous coherent order, lower only the minimal segment confidence,
create exactly one cooldown-bound FOC-043 opportunity, and perform no draw.
Repeat inside `/order` with another unaffected group and prove the next pair
appears immediately; surface the result only at the later command boundary.
Cross the cooldown and verify ordinary weighted admission without duplicate
tickets. Trigger repeated material uncertainty and verify that IMP-016 may
propose, but never create, an investigation Brick.

Repeat after both supporting edges decay below relevance. The same `C > A`
answer must become current without UX-O06; stale evidence remains inspectable
but has zero current influence. Sweep decay horizon, fresh threshold,
transitive path penalty, provocative target rate, no-candidate fallback, and
fixed random streams. Explicit `/order` must never emit the provocative pair.

Skip the provocative pair once with another eligible transitive-only pair in
the same sibling group and verify immediate UX-O01 replacement without a draw,
sorter call, receipt, or confidence change. Skip again and validate UX-O10,
pair-specific cooldown, unchanged inferred order, and no provisional placement
or unresolved-review increment. Replay with no alternative and prove the first
skip reaches the same result. Cross cooldown and show that the independent
sampler may consider the pair again without treating it as a durable ticket.

Create the fresh cycle `A > B > C > D > A`, enter uncertainty, and verify the
first UX-O07 triad is deterministically `D`, `A`, and `B`. Choose `D`; if the
remaining cycle is `D > B > C > D`, verify the next triad is `D`, `B`, and `C`.
No screen may say `right now`, present all four as one giant choice, or ask a
triad after coherence. Replay a second uncertainty on the first and later
triads and prove both end through the same UX-O09 semantics.

### SCN-IMP-004 — Honest two-Brick importance aid

From UX-O01 press question mark and traverse every IMP-040 leaf through
UX-O11. Verify that uncertainty at Q0 and Q2 may reach the same recovery as
`no` without becoming negative evidence, while uncertainty at Q1, Q3, and
Q6..Q8 uses an alternate probe and may remain pending. At Q4 and Q5, preserve
unknown versus explicit rejection until a later `yes` or recovery decides the
path. Inspect A and B independently through read-only `/show`, return to the
exact checkpoint, and prove no event or sorter movement. Confirm both direct
directions through UX-O12 and verify one human edge only after the preview.

Reach UX-O13 with grocery Bricks, accept `either_order`, and verify symmetric,
non-transitive, pair-local evidence with no equality or strict edge. During
insertion, prove replay-stable placement immediately beside the comparator;
during maintenance, prove stable local preservation and no permanent adjacency
promise. Later record a direct human direction and verify it supersedes only
the current influence while history remains. In a separate replay, reject the
leaf without mutation.

Enter UX-O14 for missing A context, missing B context, and missing comparative
evidence. Cancel one draft, then create one ordinary investigation Brick
through complete Feed. Verify that only the A/B review is suppressed, A and B
remain focusable, and completing or explicitly closing the investigation adds
high bounded comparison pressure without choosing a direction. Exercise one
eligible nearby comparator without skip evidence, then UX-O15; accept its
provisional position and verify low confidence, future review, and no edge,
equality, `either_order`, or skip. Replay assisted markings and one proposed
investigation title without allowing assistance to bypass any confirmation.

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

Serve an undecomposed `project` and an `atomic_task` through the same UX-F01
`Work:` grammar. Skip the atomic Brick with symptom `big`, enter UX-S06, and
exercise UX-B00 from its empty first line through two parts and empty Enter.
Accept the resulting UX-B01 break preview. Verify that its identity survives
reclassification and that neither its Nature nor a
large-sounding title opened decomposition by itself. Repeat through explicit
`/break` and verify that confirmation records no fabricated `big` evidence. The
decomposed parent must then disappear from execution while selection descends
to its incomplete children. Complete the final child and verify that the
parent returns only as UX-F11, never as Work and never already completed.
Exercise direct parent completion, contextual Feed of another child,
review-only skip, uncertainty, and palette child reactivation. Confirm that a
new child invalidates the review and restores descendant execution. Title
grandeur alone must not trigger a different screen.

### SCN-FOC-005 — Semantic opportunity granularity

Generate `finite_work`, `repeatable_run`, `habit_window`,
`living_checklist_run`, and `finite_checklist_run` opportunities. Verify that
they may reuse shared `Work:` composition while retaining independently typed
payloads and accept, skip, run-completion, and terminal transitions. Reject a
sixth ordinary execution variant for an active `scheduled_commitment`; it must
follow hard precedence. Reject project-scope review as execution and verify
that recurring-obligation occurrences, preparation Bricks, and actionable
Dependency endpoints use `finite_work`.

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

### SCN-FOC-006 — Honest Focus assistance

From UX-F01 enter UX-F12 and traverse every FOC-048 branch. Exercise Q0 and Q2
uncertainty converging on the same recovery as `no` without negative evidence;
exercise Q1 and Q3 alternate probes and repeated pending uncertainty. Inspect
the proposed Brick through `/show`, return to the exact checkpoint, and answer
both enough and still unclear. The latter must open UX-S34 with `vague` and
record nothing until a final vague reaction. Reject that result and verify the
original proposal and random cursor remain intact.

Open UX-F13 from ordinary, cross-Domain, and N-step blocker proposals. Verify
the immutable strongest signal, bounded bonuses, admitted count, Domain or
blocker path, branch alternatives, and replay identity against the recorded
draw. Continue to Q4 and back to Q2 without recomputation. Leave the exact
explanation-specific uncertainty tree open under `OPEN-UX-004`. At UX-F14,
accept `yes` and verify the ordinary Focus and active-Domain transition;
separately answer `no` and uncertainty and verify both open UX-S33 without
being the same local answer or recording a skip.

Repeat the complete flow after invoking `/next` from an unrelated current
focus. Every question, inspection, reverse path, and unaccepted symptom
reaction must preserve the prior focus and WIP. Accepting UX-F14 alone switches
focus; accepting a final reaction for the proposed Brick defers only that
proposal. Replay powered-up and Skill summaries without persuasion, hidden
answers, automatic Focus, or a second draw.

## Day 4 — Focus and skip adaptation

### SCN-WRK-001 — Focus lifecycle

Accept focus and validate UX-F04 before any further action: focus starts
immediately, the footer remains at `18 bricks`, an inspected forecast shows
ordinary eligibility drop from 18 to 17, no second draw occurs, and the
selected `focus_started` phrase remains stable when the screen is redrawn.
Verify the ordered `[d]one · [s]kip · [/] more...` action strip.
Open `skip`, cancel the symptom screen, and confirm that no skip evidence or
state change occurred. Replay powered up and allow only the bounded UX-065
paraphrase. Close and reopen five minutes later; validate sober UX-F05 with no
event, draw, repeated phrase, or premature stale-focus question. Advance to
the configured boundary and validate UX-F09 as the same continuation rather
than a lottery opportunity: exact action order, `. Last activity` with one
space, one truthful timestamp, no personality line, and no implied work
duration. Accept `yes`, verify one check-in and return to UX-F05 without a new
WIP, focus interval, or draw; separately test `skip`, uncertainty, completion,
close/reopen, and no mutation before a reaction. Then switch to another Brick
through `/next`: cancel the first proposal and confirm that the old focus
survives, then accept a second proposal and confirm that the switch is atomic
while the old Brick remains WIP. Inspect several WIPs and return one to idle
through UX-F10. Verify its `Review:` grammar, `Last focused` temporal fact,
and exact action order. Exercise `resume`, review-only `skip`, `done`, and
`return to idle`; confirm that review skip does not open symptom diagnosis and
that idle records no completion, work skip, cooldown, or `paused` Brick
state. Validate UX-F06, one current focus, honest WIP and focus-interval
history, and unchanged Domain and importance. In a separate replay, select direct
`done` from current focus and validate UX-F07: no intermediate confirmation,
one atomic completion that closes the focus interval and clears focus, one
stable `work_completed` result, and a contextual `/undo` that can restore the
prior state when its preconditions still hold. Verify that the result performs
no automatic draw, renders `[n]ext`, and enters the ordinary `next` pipeline
only after `n`. Verify that this result contains no binary question or `no`
action.

### SCN-WRK-002 — Symptom then reaction

Open UX-S01, Escape without mutation, reopen it, select `tired`, and enter
UX-S07. Verify its exact `easier work`, `change subject`, `pause for now`,
`skip anyway`, and uncertainty grammar; prove that merely entering the screen
records nothing and that `change subject` was never presented as a symptom.
The reaction consequences remain to be completed before validating active
Domain and pause behavior. Choose `easier work` and validate UX-S08 with three
replay-stable currently executable candidates, same-Domain preference, no
default, and positive admission for missing effort. Cancel once and prove no
mutation. Then select one number and verify a single atomic `tired` reaction,
served-Brick cooldown, complete shortlist provenance, weak relative-effort
evidence, strong contextual forecast evidence, and ordinary UX-F01 proposal
for the exact selected Brick without a second draw or automatic focus. Repeat
from current focus and prove only the served focus is closed and left WIP;
repeat while another Brick is current and prove that unrelated focus remains.
Reopen UX-S07, select `change subject`, and validate UX-S09: positive wording,
four complete Domain paths, no dumb default, deterministic nonrepeating
`[m]ore options...` pages, reverse-page navigation without evidence, and the
local `[/] menu...` label opening the unchanged command palette. Select one
target and verify the current-side branch inferred from the paths' divergence,
one target-scoped draw, decaying source fatigue and target affinity, positive
later probability everywhere, no automatic focus, and no active-Domain change
before focus acceptance. Exercise same-parent, different-parent, and
different-root targets. Keep no-target, no-Domain, and multi-membership cases
open rather than guessing. With an eligible meta-opportunity, verify the
separate `organize and review` action, one draw outside the source branch from
the versioned organization family, subsequent FOC-041 affinity, and no Domain,
Brick, importance rewrite, or persistent-mode claim. Verify that the option is
omitted when the family has no eligible member and that `[s]kip anyway` records
only the carried symptom plus cooldown. Reopen UX-S07 and choose `pause for
now` from a current Brick, an unstarted proposal, and a proposal while another
Brick is current. Validate one atomic `tired` reaction and cooldown in every case; only
the served current focus may be closed and left WIP. Verify UX-S10's truthful
state sentence, optional replay-stable `safe_end` phrase, sole `[/] more...`
action, no draw, no automatic process exit, no active-Domain change, and no
persistent `paused` state. Contrast direct `/pause`, which retains neither
symptom nor cooldown.

Reopen the symptom screen and select `bo[r]ed`. Validate UX-S11 and both its
subject-change reuse and UX-S12 transformation branch. Choose short sprint and
validate UX-S15's 5/15/25-minute rows, visible 25-minute `a Pomodoro` default,
`*`/Enter equivalence, reverse navigation without mutation, and absence of a
second Focus question. Accept 25 minutes and verify one atomic `bored` recovery,
focus transition, and DAT-045 start fact with no cooldown, effort, or progress
claim. In UX-S16, advance the canonical clock while checking that the display
derives its countdown from the fixed target and emits no per-second events.
Exercise a non-redrawing terminal's absolute-end fallback. Let the target pass
while a text draft is open: preserve the draft, revalidate at the next safe
boundary, then render UX-S17 without calling the sprint complete. Exercise
continue, another sprint, done, and pause on independent replays and verify one
truthful terminal outcome per timebox. Confirm elapsed and continue leave the
Brick focused and WIP, another sprint reopens UX-S15 with the prior duration,
done follows immediate reversible completion, and pause leaves WIP without
adding another symptom. Keep the exact custom-duration chooser open rather
than accepting an unbounded guess. Accept visible decomposition and verify
`bored` plus recovery with no redundant cooldown.
Enter UX-S13, exercise all four mechanical classifications and uncertainty,
then inspect UX-S14: deterministic editable prefix, no preallocated handle,
complete sibling/Domain/Dependency structure, lazy `atomic task` claim, and no
default. Reject and reverse without mutation; edit the title with the dumb
English reminder; finally accept one prerequisite atomically and verify one
new enabling Brick, local importance evidence, `bored` recovery, Dependency,
and no cooldown. Replay one attributed assisted proposal and prove rejection
returns to the unchanged dumb classifier.

Select `fear` and validate UX-S18 without mutation, a risk axis, or a default.
Enter UX-S19 and UX-S20 independently; verify the quiet English reminder,
ordinary editing, empty-input reverse navigation, and no generated placeholder.
Submit one validation and one safer-step draft, inspect both UX-S21 variants,
then reject and reverse without evidence. Accept each on independent replays
and verify one sibling enabling Brick, effective Domain, Dependency, local lazy
importance evidence, and `fear` recovery with no cooldown; only validation has
phase `validation`. Enter UX-S22, select an existing ExternalEntity and create
one through `New person or company...`, then exercise all UX-S23 support forms.
Verify request plus successor Wait for advice, one unscheduled enabling Brick
for collaboration, and the existing preview/approval lifecycle for delegation.
No unaccepted route may record `fear`, fabricate an Entity, schedule a meeting,
or delegate work. Replay one attributed assisted suggestion and prove rejection
returns to the corresponding unchanged dumb route.

Select `vague` and validate UX-S24's content-versus-work distinction without a
new semantic axis or default. Enter a goal in UX-S25, reject and edit UX-S26,
then accept it and verify one revision of the Raw attached as description plus
`vague` clarification
without a Brick, Dependency, cooldown, importance, phase, or lifecycle change.
Preserve a current focus and return an unstarted proposal to ordinary Focus
consent. Exercise `information` through contextual collect-more-context Feed
and all UX-S27 first-step routes: decomposition, learning work, typed support,
and direct skip. Confirm only an accepted existing preview records `vague` and
recovery, while real enabling structure replaces cooldown. Keep generic Raw
revision-event encoding under `OPEN-RAW-001`. Reject one attributed
assisted proposal and prove the original dumb checkpoint and text survive.

Select `hard` and validate all UX-S28 recoveries without a default or an
EffortProfile inference. Accept decomposition and verify `hard` plus `break
into smaller parts`, never a silent rewrite or duplicate `big` symptom. Enter
UX-S29, cancel once, then submit learning or practice work through ordinary
Nature confirmation and the full enabling preview. Independently exercise the
existing better-way and typed-support routes with `hard` carried. Confirm that
only an accepted final preview records the symptom and that real Dependency or
child structure replaces cooldown; direct skip records only `hard` plus
cooldown. Reject one assisted proposal and recover the exact dumb checkpoint.

Select `less important` and validate UX-S30 without mutating importance, time,
or Domain. Enter lower ordering, Escape before the first comparison, then
answer canonical `more/less` pairs through IMP-039 and verify that only the
first real judgment commits the symptom, reaction, cooldown, and focus close;
the final position must follow evidence even when it remains unchanged. Test
the no-lower-sibling educational result. Independently accept `later` with a
visible absolute instant and verify only `not_before`, with no importance
rewrite or redundant cooldown. Choose a full-path target Domain, verify one
FOC-047 scoped draw with no source fatigue or target affinity, and change
active Domain only after accepting replacement Focus. Direct skip preserves
order, dates, and Domain. Keep exact custom date and no-target/multi-membership
edges in their owning open decisions. Then verify `[b]locked or waiting`,
`bo[r]ed`, `[l]ess important`, and the
unchanged `[d]one` binding. Confirm that `n` is not accepted as the symptom
shortcut, that every symptom family retains its icon, and that no personality
message appears before a final reaction commits the skip. From a reaction
screen, verify that `Escape`, `Backspace`, and `Left Arrow` each restore the
exact symptom checkpoint without mutation; from the symptom screen, verify
that they restore the prior Focus checkpoint. Repeat while editing text and
while selecting in a palette to prove that Backspace and arrow keys retain
their local editing or selection meanings.

Select `other`, enter verbatim text in UX-S31, and exercise edit, no,
uncertainty, and reverse navigation in UX-S32 before accepting one replay.
Verify that only yes records `other`, the exact text, cooldown, and the served
focus close while retaining WIP; no Raw, custom symptom, blocker, Wait, Domain,
or importance claim may appear. Accumulate repeated relevant examples under a
fixed calibration profile and verify one separate taxonomy-review opportunity,
never automatic vocabulary mutation or historical rewriting. In an assisted
replay, reject one attributed existing-symptom suggestion and confirm unchanged
UX-S32; accept another and prove that it opens the existing reaction without
committing either classification or skip.

Select `big` and validate UX-S06. Cancel `break` after drafting parts and prove
that no Nature, child, symptom, or comparison survives; replay through UX-B01
and accept the complete structure as one atomic mutation. Separately cancel
and then accept `collect more context` and `learn about the subject`. Each
accepted route must create exactly one contextually fed enabling Brick, settle
its ordinary Nature and local importance, add one Dependency into the served
Brick, and record `big` plus its recovery without a redundant cooldown. Choose
`skip anyway` and verify only `big` plus cooldown. Exercise reverse navigation
from UX-S06 and confirm that `project` Nature, title wording, and an unaccepted
assisted suggestion never invoke break.

Replay decomposition in powered-up and Skill modes with evidence from the
title, Raw attached as description, linked material, and related Bricks.
Validate UX-B00A
with `yes`, `edit`, `no`, uncertainty, and no `*`; every route must reach the
same UX-B00 or UX-B01 envelope and canonical CLI validation. Exercise UX-B00B:
Tab copies one suggestion without submitting, ordinary input dismisses it,
and weak or conflicting evidence renders exact dumb UX-B00. Verify the
title-specific English hint in dumb mode and no durable handles, titles,
comparisons, Natures, symptoms, or children before UX-B01 acceptance.
After acceptance, verify that all children exist atomically as `atomic_task`,
retain claim-scoped `break_default` Nature reviews, and occupy one
low-confidence provisional sibling run in entered order. No importance
question may delay the transaction, and the sequence must not become human
comparison, Dependency, or execution-order evidence. Later maintenance starts
from that run and may surface lazy Nature and importance reviews. In the
assisted replay, verify separate visible AI provenance and lazy review for
each proposed Nature, importance run, and Dependency even after accepting the
full preview.
Validate the exact UX-B01 composition without draft handles or a technical
ontology preamble. `edit` and reverse navigation must preserve every draft;
`no` must discard them and restore the `big` or direct-command origin without
evidence; uncertainty must restore the same preview after explaining its
claims. Accept once from each origin and verify that only the `big` route
records the symptom and recovery. In the assisted replay, render only explicit
Nature, Dependency, or starting-order exceptions with `AI-suggested · review
later`; the unchanged baseline must not be repeated as assisted judgment.
Accept UX-B01 and validate UX-B02: one mutation, three newly durable handles,
21 active Bricks, seven Raws, and seven unresolved reviews. Confirm that the
three `nature_review` opportunities and one `importance_run_review` all enter
the replay-stable lottery immediately with low positive weight. Use one fixed
stream where Work wins and another where a new review wins first. Skip that
review and verify review-specific cooldown without served-work diagnosis or a
lower unresolved count; settle one Nature claim and verify the count falls to
six. UX-B02 itself must not draw, focus the first child, or imply execution
sequence; only `[n]ext` enters the ordinary pipeline, while the palette exposes
contextual undo and inspection.
Force one child `nature_review` to win and validate UX-N01 in factory and
assisted-source variants. Confirm the current Nature and verify direct human
judgment, retained source history, exactly one resolved marker, and a footer
change from seven to six reviews without an automatic draw. Replay `change`
through the canonical existing-Brick Nature choice and consequential preview;
cancel once without mutation, then accept another Nature and resolve only the
same marker. Skip once and verify review cooldown, seven unresolved reviews,
and no UX-S01. Uncertainty and reverse navigation must restore the exact
pending opportunity. No variant may show `*` or an internal source identifier.

Force `importance_run_review` to win and validate UX-O01 without `Review:` or
`*`. In lottery cadence, accept exactly one relation and validate the compact
UX-O04 `Importance recorded` result without repeated subjects or proposition.
Verify a stable no-draw result, retain the marker when the run remains
unresolved, and record an `importance_maintenance` continuity bonus. Use fixed
streams to show both a subsequent same-family win and an unrelated
positive-tail win after `[n]ext`.
In a second replay, let the same answer settle the run and verify the equally
compact `Order reviewed` variant and one fewer unresolved review.
Exercise first-skip nearby replacement, second-skip cooldown, uncertainty, and
reverse navigation. Then enter `/order` without an argument and validate UX-O02
with `all groups` first and marked as the factory default, contextual group and
Domain rows, and exact counts. Prove that `a`, literal `*`, and Enter each start
the identical all-groups scope, while Enter and `*` remain unbound on a finite
choice without a visible default and retain editor semantics in input. Select
each scope in fixed replays. Use `pick`, direct `#` input, a
partial Brick-title query such as `Bring someth`, and a partial Domain query to
prove autocomplete searches handles, titles, and paths; renders complete Brick
references; inserts canonical arguments; rejects ambiguity; and never offers
creation. A Domain or all-groups session must traverse independent sibling
runs without emitting a cross-parent pair.
Enter `/order` from the same evidence state and prove that each accepted
relation immediately renders the next pair until coherence or exit. Both
cadences must produce the pair sequence and final order required by the same
resumable `org-sort-tasks` state; neither may introduce another sorting
algorithm or treat entered position as human evidence. Leave an unanswered
pair with Escape and empty-input Backspace and validate UX-O03 with all earlier
answers retained; use `resume` to restore the same checkpoint and `next` to
return to the global draw. Separately use Left Arrow and prove it offers undo
instead of pausing. Complete the scope and validate the coherent result with
no automatic draw or persistent `paused` state.

### SCN-WRK-003 — Waiting versus blocked

Enter the common `[b]locked or waiting` route and classify each branch in
UX-S02. Verify that another task opens UX-S02A; select and cancel an
existing-Brick search, create and cancel an enabling-Brick Feed route, and
prove that neither leaves a partial Brick, relationship, symptom, or cooldown;
after submitted contextual text, prove that its preserved Raw remains in the
Inbox. Then complete each route and verify
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

### SCN-WRK-005 — Honest symptom discovery

From UX-S01 choose uncertainty and traverse UX-S33 to every WRK-095 leaf on
independent replays. At each Q0..Q7 split exercise `yes`, `no`, its WRK-096
alternate probe, repeated uncertainty, and reverse navigation. Verify that one
question is visible at a time; the reached symptom is the principal obstacle
for this interaction rather than a claim that all other symptoms are false.
At UX-S34, reject one result into the unchanged direct symptom screen, restart
one tree through uncertainty, reverse to its decisive question, and confirm
each leaf. Confirming `other` must open UX-S31; every other result must open
its existing canonical reaction. Prove that no tree answer or leaf
confirmation records a symptom, skip, cooldown, focus change, Domain signal,
or random draw; only an accepted final reaction may do so. In paired assisted
replays, accept and reject attributed `yes` or `no` markings while preserving
the exact dumb tree and confirmation.

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
change. Skip the released bill occurrence, verify one immediate cooldown, and
then verify that it remains open while avoidance and temporal evidence may
increase its later selection pressure. A later period must not erase it.

### SCN-REP-001 — Read again

Complete `#rtfea`, request another reading in six months plus or minus three,
record one deterministic date, keep its importance position, and ensure a
batch of articles receives distinct replay-safe dates. When its next
`repeatable_run` is served, expose the prior execution as
`Last completed: <absolute date>` in secondary context without turning that
history into another ticket, deadline, or primary prompt. Validate UX-F08:
the screen retains ordinary `Work:` and `Focus?`, accepting starts another
execution of the same Brick identity, and no occurrence, replacement,
importance insertion, or Nature-specific `Read again?` prompt appears. Enter
the skip diagnosis and verify that merely opening it records no outcome. After
a finalized skip, verify one immediate cooldown followed by ordinary
repeatable availability and aging, with no missed window, debt, overdue
occurrence, or gap in a compact history.

## Day 6 — Habits and delegation

### SCN-PRC-001 — Blocked habit

Advance a swimming window while `#stpw` remains blocked by `#fsp`.
Validate no `not_done` outcome and no streak loss.

In an unblocked replay, skip one applicable fixed swimming slot and verify
that the slot closes with the canonical unfulfilled outcome rather than
returning as overdue work. Then model walking three times in one week as a
quota window: skip one offer, observe its cooldown, and verify that the same
window remains eligible while the quota is unmet and achievable. Only the
window boundary derives missing outcomes from an unmet quota.

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

Run separate Delegations with `once`, `every`, and `explicitly none`. Keep
internal reviews possible in all three. Under `once`, reject a draft and fail
one delivery without consuming the policy, then record one successful
follow-up handoff and prove that later unresolved reviews cannot automatically
propose another. Under `every`, require a fresh preview and approval for every
new outbound proposal. Under `explicitly none`, create no automatic outbound
proposal while allowing an explicit human-initiated message or policy change.
Verify that internal review and outbound approval are distinct local
opportunities on one subject and retain separate histories and cooldowns.
Under `every`, record two delivered follow-ups without a meaningful outcome
and render UX-D01 instead of another automatic proposal. Exercise its soft
cap: `continue` permits exactly one more preview without resetting evidence;
`take it back` and `reassign` require reconciliation; `escalate` enters a
separate uncommitted Brick flow; and `skip` changes no Delegation state.

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

### SCN-SRCH-001 — Global search without losing the current flow

From a finite choice, a text draft with a non-terminal cursor, and a nested
provisional checkpoint, invoke `/search` and `Ctrl-F`. Search across a Brick,
Raw, ListEntry, person or company, Domain, and RawShelf; require visible human
kind labels, bounded deterministic pagination, and a read-only inspection
round trip. Escape through the result, result list, and search entry and verify
that the exact original envelope, draft, cursor, selection, and checkpoints
return without an event or another draw. Validate empty-result recovery and
prove that global selection cannot fill a contextual typed selector. Confirm
that `/find` is not accepted as a core alias and that event queries remain in
`/history`.

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

### SCN-ARC-001 — Out-of-date Work and one later relevance review

Serve `#rrsr "Review Rock Splitter rules"`, enter skip diagnosis, and choose
`o[u]t of date`. Prove that archive, replacement, update, and defer remain
different reactions. Archive it and verify one atomic transition to
`archived`, preserved identity/history/relationships and importance evidence,
closed focus/WIP, no ordinary skip cooldown, exclusion from executable Work,
and exactly one low-weight `archive_relevance_review`. Immediately undo and
redo the archive once using typed events; no history may be erased.

Replay from the archived state until the lazy review is selected. Exercise
`skip` without changing lifecycle, then on separate replays verify `keep
archived`, restoration of the same identity near its recorded sibling
neighborhood with one lazy importance review, update-and-restore after an
accepted edit, and explicit supersession by newer Work. Keeping archived must
resolve the one automatic review without creating a periodic nag. Search must
still find the Brick throughout. Run the same transcript for an archived child
and stop at the explicit `OPEN-TREE-001` boundary rather than inventing parent
closure semantics.

Enter UX-S37 independently from direct `/update #brick`, active `update it`,
and archived `update and restore`. Verify all seven semantic purposes, the
neutral `What do you want to update?` question, no dumb default, read-only
`/show` round trip, exact reverse navigation, and absence of a generic field
patch, Plan entity, `/edit` alias, or `/plan` alias. Direct entry must neither
require nor record a skip symptom and must resolve an omitted palette target
only when exactly one Brick is identified. First
exercise `meaning`: rename through selected prefill and the complete From/To
preview, then prove that UUID, `#handle`, parent, sibling order, relationships,
Domains, lifecycle, WIP, and focus remain unchanged and the former title does
not become an alias. Unchanged title submission must be an event-free no-op.
In separate description replays, create an ordinary text Raw plus its
`RawLink(role = description)` when absent; revise the same Raw identity when
present; preserve earlier revisions; mark an existing English normalization
stale; list every other affected non-description consumer; and detach without
deleting or archiving the Raw. Reject a second active description role for
either the Brick or the Raw rather than silently copying. Verify there is no
Description field, entity, or Raw subtype. Keep only generic Raw revision
encoding open under `OPEN-RAW-001`. Exercise the accepted UX-159..161 grammar:
selected replacement, arrow selection collapse, literal slash, newline
insertion, multiline paste with a trailing newline, `Ctrl-D` review, unchanged
and changed Escape, keep/discard/continue, global search suspension, crash
restoration, empty-new no-op, and explicit removal. Then exercise UX-162 with
an explicit argv editor, `$VISUAL`, `$EDITOR`, unavailable configuration,
unchanged text, changed multiline text, empty text, nonzero exit, a GUI command
missing its wait flag, terminal restoration, permission-`0600` temporary
material, cleanup, and the unchanged canonical confirmation boundary. Verify
that executable Pack code never receives process or file authority.

In further separate replays accept one Nature/behavior, plan, timing,
Domain/relationship, and source-reconciliation change through its typed
preview. A direct edit must record only that mutation. The first edit reached
through the active stale route must record `out_of_date` atomically;
inspection and rejected drafts must not. Confirm that each UX-S38 receipt has
an independent undo boundary, that `update something else` does not record the
symptom again, and that `return to Work` neither focuses nor redraws silently.
For archived Work, leaving before the first accepted edit must preserve the
archive and review; accepting it must restore the same identity and create the
one lazy importance review. Pair the dumb run with one visibly attributed
assisted branch suggestion and reject it without changing the available
grammar.

For Plan, enter UX-S48 from direct, stale-active, and archived origins. Verify
the same three human choices, no dumb default, no Plan entity, and exact
event-free reverse navigation. Choose blockers and compare UX-S49 with UX-S02:
the five situations, shortcuts, typed builders, and previews must match, while
the Plan origin alone omits `skip anyway`. Accept each situation on separate
replays and prove that direct Plan entry records only its Dependency, Wait,
`not_before`, Place, or event-condition result—never a skip symptom, cooldown,
or refusal of focus. Then enter UX-S50 from every factory Nature and verify
that the same three intents remain available with no default. Move one
compatible Brick toward parent selection
without changing Nature. For parts, distinguish a finite `project` proposal
from an open-ended `collection` proposal. For list items, distinguish finite
from continuing ownership before proposing `finite_checklist` or
`living_checklist`. Reject every incompatible proposal without creating a
child, ListEntry, relationship, Nature claim, or reconciliation event; accept
representative proposals only through the complete MOD-059 preview. Never
convert a child Brick and ListEntry into one another. Leave each downstream
structure manager and responsibility at its explicit `OPEN-PLAN-001` boundary
until its screen is reviewed.

For reparenting, cover identical, ancestor-related, partially overlapping,
disjoint, and missing direct Domain path sets, including multiple memberships
on both sides. Unequal sets must render every path and only their mechanical
relationship; the dumb core must never infer semantic distance from titles or
Domain names. In UX-S51, accept `yes, keep current Domains` and prove that only
composition and the moved root's provisional sibling placement change. On a
separate replay choose `change Domains`, reject the combined preview, and prove
that neither movement nor membership occurred. Accept it once and verify one
reversible combined action. Creation under a parent may visibly propose its
paths, but acceptance must store direct memberships; later parent movement must
not cascade a Domain change through any descendant.

In UX-S52, search by exact handle, handle prefix, and title fragment; move to
root and to an existing compatible parent on separate replays. Confirm that the
current parent is an educational no-op and that self and every descendant are
absent. Select an incompatible parent and require its complete Nature
reconciliation. Then choose `New larger Work...`, traverse ordinary title,
Nature, Domain, and structure drafting, cancel at each checkpoint, and prove no
parent identity, handle, or move was committed. Accept one complete combined
preview and prove the new parent and reparenting become visible atomically.
Powered-up and Skill may reorder the same eligible results and mark one, but
must not change eligibility or accept it. Preserve the exact query and move
draft across search suspension and reverse navigation.

For Nature/behavior, first select the current Nature in UX-S46 and prove an
event-free no-op. Traverse the full mechanical discovery route over the
existing Brick, reject its result, and verify no classification evidence was
recorded. Then reclassify `#tm "Take medication"` from `habit` to
`recurring_obligation`: collect the required schedule, render UX-S47, preserve
identity, importance, Domains, description, and all typed habit outcomes; stop
future habit windows and streak extension without rewriting history; and
release only future obligation occurrences after acceptance. Reject and edit
the preview on separate runs. Repeat with one attributed assisted Nature and
reject it back to exact dumb UX-S46. Finally exercise `OPEN-NAT-001` fixtures
for a project with children, checklist with entries, repeatable with a pending
return, obligation with open occurrences, scheduled commitment with an active
interval, and focused/WIP Work; every incompatible fact must obtain an
explicit resolution or block confirmation without silent conversion.

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

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

### SCN-UI-001 — Shared grammar and decoration parity

Before Day 1, render UX-R00, UX-M01, UX-RF01, UX-PH00, UX-H00, and
UX-A11Y00 with ANSI and emoji independently set to `always` and `never`, then
with both on factory `auto`. Strip ANSI and verify byte-for-byte semantic text,
the permanent `> ` selection cursor, stable display columns, and unchanged
action order. Suppress every emoji and prove that phase, symptom, history,
warning, success, and state meaning remains explicit in words. Reflow each
screen at 40, 60, and 80 display cells; no action may be truncated, combined,
or reordered.

Traverse phase review from every current phase and from no phase. Exercise all
four choices, clear or leave unspecified, reverse navigation, semantic undo,
and one accepted plus one rejected attributed suggestion. Phase must never
sort importance, block focus, imply WIP, or advance automatically.

Render every stable ID in the factory personality catalog at its one valid
intent transition. Verify exactly 16 unique phrases per intent, replay-stable
selection separate from forecast randomness, no phrase on a decision or
high-stakes screen, and sober continuation after restart. Replay each with
emoji disabled and one powered-up paraphrase; wording may vary only in the
assisted phrase while the intent ID, state, actions, and subject remain fixed.

Finally press one unbound letter on every finite screen family and verify the
same concise no-event recovery. Open each arrow-navigable list, move the cursor,
filter it, return, and run the selected action. `*` and Enter must select only
one visibly marked default and must never mean the `> ` cursor.

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
- feeding byte-identical compatible material again still creates another Raw;
  a later `raw_duplicate_review` renders UX-T10 and yes links the later receipt
  to the canonical root without deleting either identity, source, revision, or
  history, while grouped projection shows the receipt count;
- no records pair-specific nonduplicate evidence until either Raw changes;
  skip leaves the review pending under cooldown; question mark is read-only;
  undo restores the later Raw's prior Inbox disposition and redo revalidates
  both revisions before restoring the link;
- the suspended proposal is revalidated after that Raw commit and returns
  without a receipt screen, carrying one transient complete `Fed: +...` fact;
- pristine Feed proceeds directly to its sole Raw-triage opportunity, while a
  valid current focus remains primary after Feed or transactional triage;
- a later recorded `raw_triage` draw renders the Raw through its complete
  `+handle "preview"` reference, never through a Brick `#` handle, and asks
  the independent-Work question;
- `no` ranks compatible existing destinations using only inspectable dumb
  evidence; `[m]ore matches...` pages that set, `[s]earch...` autocompletes
  across it, and `[c]reate a new group...` opens behavioral discovery without
  asserting that unseen candidates are unsuitable;
- the Raw-triage question-mark tree reaches Work or destination selection only
  through the standalone-Work consequence, while repeated uncertainty keeps
  the Raw in the Inbox;
- `keep as standalone raw material` records one disposition without creating
  a shelf, link, Brick, archive, or importance position;
- new-group discovery creates no generic Group object and reaches explicit
  list, RawShelf, or independently focusable Work previews;
- selecting `#bg "Buy groceries"` proposes a ListEntry and duplicate review
  without turning that entry into a global world object; the source Raw keeps
  its independent `+` reference;
- open and resolved duplicate cases expose keep/reopen, add or change
  quantity, and distinguishable-separate-item behavior;
- if the Raw is instead materialized as Work, no hidden Nature fallback
  exists: direct factory Nature choices and guided `[?] I don't know` precede
  any compatible Template, and the exact parent and local importance position
  are visible before the Brick is committed;
- title, evidence-backed optional parent, explicit direct Domains, duplicate
  suspicion, and each binary-insertion answer remain draft facts; root and no
  Domain incur no extra screen without candidates but remain editable and
  visible in the final preview;
- a suspected existing Brick offers use-existing, create-separate, and
  read-only differences without `merge`; use-existing creates no Brick;
- final yes atomically creates handle, Raw source relationship, disposition,
  exact sibling position, and accepted comparisons; no or cancellation leaves
  no Brick or comparison evidence;
- first ordering skip tries a nearby sibling; with none, low-confidence
  placement completes rather than repeating the same question; contextual
  `/tie-break` creates no human edge;
- the creation result performs no draw, and pressing `n` reaches the ordinary
  Focus proposal. With no sibling, the first Brick occupies the sole root slot
  without a ceremonial comparison.

From any reference-capable field in this flow, type `+` and verify that Raw
autocomplete searches handle, original material, current English
normalization when present, and source label or filename; every result uses
the complete `+handle "preview"` rendering. Select one result and verify that
the action stores its UUID. Paste the same visible text without selecting an
autocomplete result and verify that it remains literal text rather than a
silent Raw reference.

Count every screen and keypress in the dumb replay. Candidate-free root and
Domain paths must omit their selectors, while assistance may shorten only the
declared proposal gateways. Report any form-like friction as UX evidence rather
than deleting a canonical fact from the final preview.

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
completed work. From UX-RA00, exercise each closed Raw role, two shelves, two
direct Domains, archive/unarchive, and one text revision that makes an accepted
normalization stale. Verify that no relationship inherits to a child Brick.

Run `/translate` over one Portuguese title, one Portuguese text Raw, one URI,
one blob, one stale normalization, and one archived Raw. Dumb mode must expose
the editable queue; assisted mode may prefill the same field. Verify title
rename versus same-Raw normalization, unsupported non-text reporting, archived
scope opt-in, original-content search precedence, interruption/resume, and
per-candidate atomic history.

Then attach a manual URL SourceBinding and replay unchanged, changed, missing,
unauthorized, relocation, detach, corrupt snapshot, and byte-identical restore.
Changed content must require same-Raw revision, derived Raw, or unrelated;
every failure preserves local material and Work state. Rebuild the dataset and
verify identical current revision, baseline, check schedule, and degraded
state.

### SCN-FED-004 — Skill and local-web mirror

Only after SCN-FED-001 through SCN-FED-003 are accepted, render their existing
envelopes in the operator Skill and shipped local-web reference. Validate
almost-literal parity; do not let either mirror supply a missing dumb-core
path. A future mobile client reuses this conformance scenario.

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

### SCN-JUD-001 — Impact, maturity, and effort

Open `/impact` for a root and traverse UX-J00 without selecting a class.
Verify that no row is a default, missing impact stays absent, and invoking the
same command on a child cites and routes to its root. Select every class on
independent replays. With no selected evidence, accept UX-J01's visible
`SPECULATIVE` default and prove that only maturity—not class—had a default.
Attach a Description Raw, an independent supporting Raw, a completed POC, and
one real-setting outcome in turn. Traverse every IMP-051 answer and
uncertainty branch; prove that Description alone cannot become support and
that supported, validated, and observed each cite applicable evidence. Make
that evidence stale, contradicted, removed, and scope-inapplicable. Verify one
`impact_maturity_review`, unchanged public judgment before acceptance, and
explicit retain, demote, revise-class, and clear outcomes.

Compare roots through UX-J02. Exercise more, less, about-the-same, skip,
outcome inspection, investigation proposal, and no-basis behavior. Prove that
relative evidence alone assigns no class; then bound one root against reviewed
class anchors until a single class remains and require explicit confirmation.
Create recent `A > B > C > A` impact evidence and traverse UX-J07 through
changed, revise-answer, each three-way winner, about-the-same, and repeated
uncertainty. Repeat after evidence decay and verify that the new human answer
wins without interruption while old history remains. Trigger one never-direct
transitive validation and prove its primary screen is indistinguishable from
ordinary UX-J02, its skip is bounded, and explicit `/impact` never injects it.

Open `/effort` for finite, decomposed-parent, repeatable-run, habit-window, and
unbounded-standing subjects. Verify IMP-047's exact comparison unit or an
educational refusal, all eight UX-J04 classes, current EffortProfile references,
no default, and no stored hours. Run UX-J06 against zero, one, and three
reviewed exemplars; exercise more, less, about-the-same, skip, one isolated
class, and a remaining-class interval. Run UX-J05 with two and four comparable
units, choose each row, and verify only relative easiest evidence. Create and
resolve a fresh effort cycle through UX-J07. Change scope and verify `review
due`; import actual hours and prove they remain evidence rather than rewriting
the historical class.

For both axes, accept and reject one powered-up/Skill proposal. Acceptance must
remain visibly provisional with attribution until a later human review;
rejection must return to the byte-equivalent dumb route. Inspect compact,
structured, sparse-JSON, forecast, and TaskJuggler projections and verify that
ordinary views expose no numeric confidence, missing fields remain omitted,
and planning hours come only from the recorded profile version.

## Day 3 — Forecast, Domain, and blockers

### SCN-FOC-001 — Same-subject continuity

With Rock Splitter active, draw related work and validate the Domain-affinity
explanation without a hard filter.

### SCN-FOC-002 — Positive-tail cross-Domain draw

Use a recorded draw in which `#bg "Buy groceries"` wins. Validate UX-F02:
no preliminary switch prompt; `yes` changes Domain; `skip` and non-focus
palette actions do not. Give one Brick two equally specific memberships and
verify the recorded local tie draw, visible chosen path, inspection of tied
alternatives, and no duplicate ticket. Sweep fixed streams with neglected
low-chance Work: probability and aging remain positive, the Focus forecast in
`/list` explains
them, but no hidden Nth-draw service rule forces an outcome.

### SCN-FOC-003 — N-step blocker path

Draw `#rlav "Release Little Ant v1"` and resolve through `#rio` to
`#dtimc`. Validate UX-F03, local weighted branch evidence, complete `?`
context, and no importance rewrite.

Attach one Dependency to a decomposed parent and another to one child. Verify
the parent blocker is resolved before child descent, while the child blocker
applies only after that child wins. Resolve a blocker through another
container, a branch, Wait, temporal gate, and corrupt endpoint; every result
must retain the original scoped intention and never turn a non-Brick endpoint
into Work.

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

Generate every FOC-054 non-execution row and validate its required payload,
actions, skip transition, and one-subject ticket. Importance run, validation,
and recalibration remain distinct because their trigger and skip consequences
differ even when they reuse the proposition screen. Reject a hybrid payload,
generic review/interaction variant, Pack-defined row, or action outside its
variant. Finally add deadline pressure, one discreet warning, and explanatory
context to a subject and verify that none creates an additional opportunity or
top-level ticket by itself.

### SCN-DOM-001 — Domain forest, scope, and recovery

Create roots `Orbit` and `Personal`, move `Rock Splitter` within the Orbit
subtree, rename an ancestor, merge two sibling Domains, archive/restore the
subtree, and dry-run every mutation. Verify identity-stable full paths, unique
sibling names, preserved direct memberships, no member lifecycle changes,
active-focus/scope reconciliation, no exclusions, and atomic undo. Count R&D
recursively with one multi-member Brick and require direct, descendant, and
deduplicated unique totals.

Run UX-DM00 for one suggestion, stay within, and prefer. Confirm that hard
scope ignores prior continuity for admission, persists only for stay-within,
and may follow a blocker outside the subtree while explaining why. Exercise
UX-DM01 with and without actionable gates and contextual Feed. From tired,
bored, and less-important recovery, cover a multi-Domain source, no-Domain
source, several target pages, and UX-DM02 with and without organization work.

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
draw. Continue to Q4 and back to Q2 without recomputation. Exercise UX-196
`understand_subject`, including inspection, restatement, and repeated pending
uncertainty. At UX-F14,
accept `yes` and verify the ordinary Focus and active-Domain transition;
separately answer `no` and uncertainty and verify both open UX-S33 without
being the same local answer or recording a skip.

Repeat the complete flow after invoking `/next` from an unrelated current
focus. Every question, inspection, reverse path, and unaccepted symptom
reaction must preserve the prior focus and WIP. Accepting UX-F14 alone switches
focus; accepting a final reaction for the proposed Brick defers only that
proposal. Replay powered-up and Skill summaries without persuasion, hidden
answers, automatic Focus, or a second draw.

### SCN-FOC-007 — Fixed-point forecast calculation

Replay every reference vector and boundary in the
[deterministic calculation profile](../deterministic-calculation-profile.md).
Verify exact integer factors after each named rounding step, correlation-key
collapse, strongest-plus-extra pressure, current-Domain affinity, family and
fatigue decay, canonical candidate order, rejection sampling, local
opportunity normalization, and hierarchical leaf projection. Sweep every
factory parameter while holding events, clock, and random cursor fixed. No
admitted weight reaches zero, a displayed rounded percentage never feeds a
draw, and replay under an older recorded profile hash remains byte-identical.

### SCN-PLACE-001 — Lightweight Place conditions

From the dumb blocked-or-waiting route, classify `#bg "Buy groceries"` as
requiring `grocery store`, accept UX-PL00, and prove that no Place entity,
handle, Domain, Wait, or `not_before` is created. Draw the same Work without a
location observation, reach UX-PL01, answer no, and verify one hour of local
place deferral without skip evidence or active-Domain change. Replay from the
same draw, answer yes, and verify that the exact original `Focus?` returns
without a redraw and still requires acceptance.

Through Context maintenance, add a preferred `home office` label and exercise
matching, nonmatching, expired, and missing attributed adapter observations.
Verify strongest-only bounded weighting, neutral unknown state, removal
preview, autocomplete of prior labels without global identity, and paired
assistance that cannot infer where the human is.

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

Replay each WRK-139 command from valid and invalid state. `/focus` must start
idle Work and resume WIP through the same Focus transition; `/pause` must
require current focus and preserve WIP; `/return-to-idle` must produce UX-F15
from current and non-current WIP without an outcome; `/done` must follow the
served Nature; `/finish` must exist only for an active checklist run; and
`/archive` must be the standing-retirement route. Reject `/resume`, `/stop`,
`/retire`, `/complete`, and Nature-specific aliases with a concrete canonical
suggestion and no mutation. Pair each with CLI, dry-run, undo, stale revision,
palette filtering, and operator natural-language mapping to the canonical
command rather than a core alias.

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
different-root targets, then the FOC-060 no-target, no-Domain, and
multi-membership routes. With an eligible meta-opportunity, verify the
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

Repeat easier-work with zero executable alternatives and validate UX-S08E:
no empty selector, no committed symptom on entry, no fabricated candidate,
and only currently usable subject, organization, pause, skip, back, and
uncertainty routes. Traverse every FOC-037 execution variant through UX-S01.
Verify the unchanged symptom grammar, WRK-123 completion dispatch, WRK-124
defer-only aftermath, checklist entry preservation, fixed-slot versus quota
habit behavior, and absence of this route for scheduled commitments.

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
adding another symptom. Enter UX-S15A, reject zero, a fraction, natural
language, and 121; then preview and start 40 minutes, verifying the displayed
absolute end instant and the same focus-consent event as a factory duration.
Accept visible decomposition and verify
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
recovery, while real enabling structure replaces cooldown. Verify the MOD-065
revision event and stale normalization. Reject one attributed
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
order, dates, and Domain. Keep only exact custom-date input for the time block.
Then verify `[b]locked or waiting`,
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

Run fixed-stream pressure replays immediately before, at, and long after
`review_not_before`. Verify zero eligibility before it, positive bounded
weight at it, monotonic saturating age afterward, one ticket, ordinary positive
competition, and no due/overdue or Nth-draw guarantee. Add review skips and
completed follow-up handoffs independently; verify cooldown, bounded retained
terms, and age reset only after a newly chosen review gate. Resolve two
comparable historical Waits and prove the factory three-day suggestion remains;
resolve a third and prove only the nearest existing preset may receive the
history-backed `*`.

Complete two explicit follow-up Bricks without meaningful response. On the
next selected review require UX-W03 instead of ordinary follow up. Exercise
wait longer, follow up again, change blocker, stop waiting, skip, uncertainty,
and every reverse path. Prove that no route sends, escalates, archives, or
completes implicitly and that a meaningful response or replacement target
resets the count. Replay UX-W02 for a human response and an event condition;
inspect evidence, keep waiting, skip, accept the positive outcome, and reject
an attributed source suggestion. Only explicit acceptance may resolve the
Wait, and every other gate on the affected Work must survive.

## Day 5 — Lists, dates, and repetition

### SCN-LST-001 — Grocery run

Create a continuing grocery list through the finite-versus-continuing question
and parse `Milk`, `2 x Coffee`, and `1.5 kg x Rice`, verifying the separated
preview fields and owner-scoped identities. Refeed Milk, add one count, then
attempt a unit mismatch and verify that no add or conversion action appears.
Open the manager, select without mutating, resolve one item directly, cancel
and reopen another, and confirm that identity and history survive.

Serve the living owner, verify that its proposal has no direct done action,
start a run, resolve listed and newly added unlisted purchases, leave one item
open, and finish without retiring the standing Brick. Crash after one item
mutation and verify the same run, stable row indices, and committed outcome on
restore. Finish a later zero-open run and verify dormancy. Repeat with a finite
trip checklist: partial finish carries entries; zero-open finish creates a
separate scope-closure review with resolved and cancelled counts; add-more
invalidates it; cancelled-only scope has no default; explicit completion is a
separate event. Exercise a list longer than nine rows, local selection from a
global search result, reverse navigation, and each declared undo boundary.

### SCN-TIME-001 — Bill and warning

Exercise `not_before`, `best_before`, and `deadline` separately. Validate one
discreet warning, overflow count, acknowledgment/snooze, and no importance
change. Skip the released bill occurrence, verify one immediate cooldown, and
then verify that it remains open while avoidance and temporal evidence may
increase its later selection pressure. A later period must not erase it.

Open UX-NOT00 before, at, and after the represented threshold. Exercise open,
acknowledge, snooze through UX-DT00..DT02, uncertainty, `/notices`, and reverse
navigation. Prove that acknowledge hides only the exact fact-revision and
threshold, snooze changes only `notice_not_before`, underlying forecast date
pressure remains, and editing the date creates a new identity. With three
equal-severity notices, advance real screen transitions and verify stable
single-line round-robin plus `+2 notices`; redraws and active text/confirmation
screens must not rotate or steal focus.

Create daily, weekly, monthly-day-31, and yearly recurring obligations through
UX-RO01, including several times and weekly weekdays. Verify the next three
anchors, timezone/DST behavior, month/year clamping, explicit not-before,
best-before, and deadline offsets, and rejection of prose/unsupported RRULE.
Tick each series twice and prove idempotent occurrence identity, repeated title,
separate occurrence label, one series importance slot, one series forecast
ticket, and local positive-tail selection through UX-RO00. Accumulate two open
bill occurrences, complete one and archive one without changing the series or
future release. Simulate 1,501 offline openings and verify a 1,000-occurrence
batch plus required continuation with no coalescing or loss.

### SCN-SCH-001 — Scheduled commitment attention

Create flight, meeting, appointment, service-window, and point-like source
examples through UX-SC00. Verify required end, start/end zones, UTC offsets,
DST ambiguity recovery, different flight endpoint zones, all-day refusal, and
one explicit point-event duration. Before the interval, serve eligible
preparation only through ordinary hierarchy. At start while ordinary Work is
focused, require UX-SC02 at the next safe boundary without interrupting a text
draft. Exercise exit, inspection, uncertainty, attend now, early missed, and
cancelled. Attend now must leave the former focus WIP and focus the commitment;
no outcome may be inferred. During and after the interval, exercise every
UX-SC03 result, status, no-draw receipt, undo, and immutable preparation
history. Confirm no generic skip, later, done, personality, or active-interval
lottery route appears.

Create two known overlaps and retain both through the explicit creation
warning. At runtime, traverse UX-SC04 in each order with no default; resolve
one and prove the other remains hard precedence. Replay with an already-current
commitment and with seven overlapping commitments to cover pagination. Attempt
Delegation on the owner and require WRK-155's educational stop; delegate one
preparation child normally and prove it never suppresses commitment precedence.
Pair dumb behavior with one accepted and one rejected attributed interval or
Template proposal without allowing assistance to invent an end or attendance.

### SCN-SCH-002 — Preparation and reschedule

Create each WRK-156 factory proposal through UX-SC01. Toggle, edit, reject,
and accept its children; verify exact Natures, relative temporal meanings,
immediate/passed disclosure, no invented deadline, no runtime Template
authority, and one atomic creation. Add one manual preparation Brick and prove
it receives no relative anchor.

Reschedule before and after preparation starts. In UX-SC05, cover pending
relative children, completed children, absolute overrides, a newly opened
child, newly future-gated idle and WIP children, passed best-before/deadline,
Dependencies, and current focus. Require an override or explicit focus/WIP
closure for the future-gated WIP case. Move the interval wholly into the past
and require attended, missed, or cancelled in the same preview. Verify one
atomic batch, dry-run identity, cancellation without partial edits, semantic
undo, stale conflict, and source/assisted proposals with no preselected yes.

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

Complete another run and traverse UX-REP00 with no prior policy: set a return,
choose manual-only, and archive on independent replays, with no default.
Configure six months plus or minus three through UX-REP01 and verify structured
fields, range validation, month clamping, deterministic chosen offset, absolute
`not_before`, unchanged UUID and importance, and no new occurrence. Complete a
later run and verify that keeping the existing policy is the sole visible
default, while changing it and leaving the result checkpoint cannot make the
Brick immediately drawable. In manual-only mode, prove ordinary `next` omits
the repeatable while explicit `/focus` can start it. Verify dry-run, crash
recovery, assisted proposal rejection, and undo before and after a conflicting
later run.

## Day 6 — Habits and delegation

### SCN-PRC-001 — Blocked habit

Advance a swimming window while `#stpw` remains blocked by `#fsp`.
Validate no `unfulfilled` outcome and no streak loss.

In an unblocked replay, skip one applicable fixed swimming slot and verify
that the slot closes with the canonical unfulfilled outcome rather than
returning as overdue work. Then model walking three times in one week as a
quota window: skip one offer, observe its cooldown, and verify that the same
window remains eligible while the quota is unmet and achievable. Only the
window boundary derives missing outcomes from an unmet quota.

Use quota three with one completion and verify that the boundary records
exactly two `unfulfilled` units. Make the remaining window blocked, paused,
and inapplicable on separate replays and prove that none fabricates a failure
cell or breaks the streak. Verify UX-H00's factual copy, real-only outcome
strip, glyph-free equivalent, no automatic draw, and explicit outcome history.

### SCN-PRC-002 — Explicit unfulfilled intention

After unblocking, attempt to end a window and validate UX-P01. Distinguish
ordinary skip, explicit outcome, and deterministic expiry.

Cross the factory introspection threshold once through three applicable
unfulfilled outcomes and once through three explicit skips inside two windows.
Validate exactly one weighted UX-H01 review, no invented cause, every existing
typed remedy, keep-unchanged settlement, review-only skip, and calm assisted
copy. A recorded cold-weather explanation may support a visible schedule
proposal, but rejecting it must restore the identical dumb history screen.

### SCN-DEL-001 — Delegation contract

Enter through Plan responsibility. Verify that `me` is an educational no-op
without an active Delegation and take-back with one; distinguish responsibility
from advice and collaboration through the bounded question tree; resolve a
target with `@` autocomplete. Exercise every WRK-032 Nature: fixed scopes omit
the chooser, project asks brick-only versus whole scope, habit points to
separate enabling Work, a released recurring occurrence follows its own
Nature, and scheduled commitment stops with WRK-155's preparation-child
recovery. Confirm that no two displayed scope rows have identical coverage.

Delegate a project-like Brick. Validate the target, scope, mandatory
`once | every | explicitly none`, 24/72/168-hour and custom review-delay
grammar, adapter/manual method, complete English message preview, approval,
follow-up, refusal/completion reporting, and no cascading parent completion.
Reject and resume every builder checkpoint; crash before final yes and verify
that only the InteractionEnvelope draft returns. Accept the preview and verify
one durable proposed Delegation with no human-execution suppression. Check all
four exact factory message patterns and attributed editing.
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

On internal review, traverse the complete question-mark tree to progress,
reported completion, refusal, and no response. Verify that progress and a
no-message review seed the next instant from their observation time, while a
delivered follow-up seeds it from handoff time. Skip one review and validate
the 24-hour cooldown without a state or effect change. Keep refusal and
reported completion as observations on the still-active Delegation until an
explicit reconciliation commits. Take responsibility back while an approved
effect is undelivered; reject it atomically, restore exact-scope human
eligibility, and require a separate approval for any take-back notice.
Reassign atomically into one new proposed record with editable inherited facts
and no suppression before its handoff. Validate completion only after ordinary
Nature closure facts, and archive/supersede only through their existing
combined previews. No path creates a generic `abandoned` outcome or Wait.

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

Under active whole-scope project coverage, add a child and verify the preview
warns that it will already be delegated and absent from human Work. Repeat for
a ListEntry. Release a recurring occurrence and verify the same derived
coverage in the result/history without a fabricated confirmation.

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

### SCN-SEC-001 — Contacts, configuration, and credentials

Add email, phone, URI, and provider-recipient ContactPoints to Alice through
UX-CNT01. Import a changed email and a missing remote contact; verify attributed
review rather than silent replacement or retirement. Configure Work Mail and
one purpose-scoped preferred DeliveryBinding without placing a secret in the
dataset or any YAML. Traverse UX-CNT00 with the preferred binding ready,
locked, unavailable, and absent. Manual handoff must remain usable, and merely
choosing a method must never send or activate Delegation.

Create `default` and `work` profiles. Validate every DAT-057 resolved path,
schema, file mode, selection precedence, no cross-profile merge, and the
redacted `/config`/CLI views. Change presentation language and prove only the
wrapper changes; canonical titles, actions, events, and structured results
remain English. Change calibration separately and prove its content hash
enters only affected future evidence. Move `integrations.yaml` without the
vault and require `unbound`, not copied credentials or provider failure.

Create a vault, inspect its age v1 scrypt header without decrypting it, and
verify work factor `2^18`, fresh salt/nonces, authenticated `vault@1` payload,
private paths, and absence of plaintext fragments. Exercise correct and wrong
passphrases, explicit lock, idle lock, logout, corrupt ciphertext, unsupported
header, backup, passphrase rotation, provider-secret rotation, atomic write
failure, and restored-old-file warning. Lost-passphrase recovery must state
that only credentials are lost and must never offer a bypass.

From a pending delegation effect, enter UX-VLT00, cancel unlock, unlock, then
return to the byte-equivalent still-unapproved message preview. Approve it only
afterward. Verify that Lua, UIAdapter, Skill, powered-up input, Interaction
Envelope, history, diagnostics, logs, process arguments, environment, UI
checkpoint, and crash report never contain the secret. A locked calendar check
must remain due without provider backoff. Finally, connect with a wrong UID,
send malformed or oversized IPC, and request arbitrary decrypt; the agent
rejects all three without exiting or revealing binding inventory.

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
and ensure a stale keypress cannot answer the replacement prompt. Replay an
unrelated concurrent change whose precondition hash remains valid and verify
safe revalidation with both cursors; then change a relevant subject and require
UX-ER02 with no carried keypress. Corrupt the integrity token, action ID, and
envelope revision separately and require typed rejection. Verify finite,
recorded, range, and omitted progress without fictional percentages.

### SCN-REF-001 — UUID identity and typed mnemonic handles

Using the existing `#rs "Rock Splitter"`, create `#rs2 "Reason Season"`,
`+milk "milk"`, `+milk2 "milk"`, and `@rs "Rita Santos"`, plus records whose
internal UUIDv7 values share arbitrary prefixes. Verify that `#` autocomplete
searches only Bricks by handle and title, `+` autocomplete searches only Raw
by handle, original or normalized content, source label, and filename, and
`@` autocomplete searches only people or companies by handle and name.
Ordinary rendering never exposes or asks the user to memorize UUIDs. Rename
both Bricks and revise and normalize both Raw records; verify that UUIDs and
handles remain stable. Explicitly rename one handle, verify the old spelling
does not resolve as an alias, retire it, and verify the allocator does not
reuse it.

Allocate handles from one long word, accented Latin, several words, digits,
empty text, punctuation only, and non-Latin text. Verify UX-201 exactly and
collision suffixes from `2`. Exercise Domain paths, Shelf names, owner-local
ListEntries, Wait, Delegation, and SourceBinding selection without inventing
new sigils. Create equal-ranked parent candidates and verify UX-203's tie
order. Paste a complete citation in prose and prove it remains literal; use it
in a typed CLI argument and require current-handle resolution plus stale-label
warning.

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

Repeat immediate undo and valid redo for every UX-198 class: Feed/create,
title and Raw revision, link/membership, importance evidence, reparent/break,
focus/completion/skip, Wait/Delegation, atomic checklist batch, and a pending
effect. For each, introduce one relevant later action and require all-or-none
typed conflict. Introduce one disjoint mutation and verify redo remains valid
only when its write-set and postcondition hash still match. A dispatched effect
must require a separately approved compensating effect, never generic undo.

### SCN-DAT-001 — Sparse projections and corrupt history

Request every DAT-052 view at schema major 1 and one unsupported major. Verify
schema-declared omission, meaningful false/zero/null, requested empty lists,
explicit blob/history expansion, and every DAT-054 filter plus cursor paging.
Inject malformed JSON, unknown event major, broken sequence, and missing
identity references separately. Ordinary startup must stop at the exact
record; degraded prefix mode must remain read-only. Run `lant doctor`, then
repair into a separate candidate, fully replay and compare it, and verify that
cutover retains the original backup and never silently quarantines evidence.

### SCN-ARC-001 — Out-of-date Work and one later relevance review

Serve `#rrsr "Review Rock Splitter rules"`, enter skip diagnosis, and choose
`o[u]t of date`. Prove that archive, replacement, update, and defer remain
different reactions. Traverse every UX-S35A leaf, its alternate probe,
reverse path, and final event-free `not confirmed` result before accepting any
reaction. Archive it and verify one atomic transition to
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
and apply MOD-083's mixed terminal-child scope review without inventing parent
completion.

Enter UX-S37 independently from direct `/update #brick`, active `update it`,
and archived `update and restore`. Verify all seven semantic purposes, the
neutral `What do you want to update?` question, no dumb default, read-only
`/show` round trip, exact reverse navigation, and absence of a generic field
patch, Plan entity, `/edit` alias, or `/plan` alias. Direct entry must neither
require nor record a skip symptom and must resolve an omitted palette target
only when exactly one Brick is identified. First
traverse UX-S37A to every purpose and the event-free no-update result. Exercise
UX-UP00..UP02, applicable-row omission, typed managers, and the unchanged
assisted baseline. Use UX-DT00..DT02 for `not_before`, `best_before`, and
deadline: verify structured date/time input, workday-start suggestion,
explicit zone and offset, DST ambiguity handling, final confirmation, and no
natural-language parser. Then
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
Description field, entity, or Raw subtype. Exercise the MOD-065 revision
encoding and the accepted UX-159..161 grammar:
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
convert a child Brick and ListEntry into one another. Exercise the ListEntry,
incompatible-Nature, and responsibility routes through their exact collectors,
combined previews, terminal results, and reverse paths.

For parts, first select a compatible parent with no children and prove that
UX-B00 opens directly without an empty manager. Reject one draft, accept two,
and verify the first-decomposition copy, atomic handles, Nature consequence,
IMP-030 run, and origin-appropriate UX-B02. Then open UX-S55 on a parent with
more active and inactive children than the visible bounds. Verify active
importance order, plain inactive states, exact overflow counts, and a
read-only `/show` round trip. Require explicit child autocomplete for every
multi-subject palette mutation. Traverse UX-S56 through yes, no, the bounded
explanation, repeated uncertainty, and every reverse gesture without an
event. Add one and then several parts on separate Plan replays; accept only
through UX-B01, preserve all existing facts, allocate the batch atomically at
the IMP-045 provisional tail, add one importance-run review, and render the
additive UX-S38 counts and handles. Repeat with current focus and with a
pending scope-closure review, proving respectively unchanged focus and the
visible FOC-039 invalidation. Make the child set stale before acceptance and
require re-rendering. Trigger a duplicate suspicion and require FED-016
without silent reuse. Enter continuous ordering from UX-S55 and verify that
only the stable UX-O03 result offers `[p]arts`; resume and next retain their
ordinary meanings. Pair one assisted draft and one attributed action hint
with the identical dumb confirmation and reject both without mutation. Leave
part-batch compensation through UX-198 and mixed child closure through
MOD-083 and UX-LC04.

For structural compatibility, mechanically replay every MOD-062 cell. Confirm
that project and collection enter Parts directly, both checklists defer only
to ListEntries, recurring-obligation occurrences do not become manual parts,
and a scheduled commitment accepts ordinary preparation children without
changing Nature, losing hard interval precedence, or inventing a relative-time
anchor. Add exactly one first child to an empty compatible project, collection,
and scheduled commitment through the one-draft additive route. Validate every
standard Template expansion against the receiving
Brick's structural capability; nested child checklists may own entries, but an
incapable root may not acquire a mixed hidden structure.

Select parts on an atomic task and traverse UX-S57 through each row, the
finite-versus-continuing probe, repeated uncertainty, and every reverse path.
Verify no Nature evidence or draft becomes durable before UX-B01. On separate
replays attempt `habit → project` and `finite_checklist → collection`: require
all available target configuration and incompatible-state reconciliation
before collection, then require the complete UX-S47 disclosure inside UX-B01.
If the all-pairs owner lacks a required reconciliation, stop with a typed
return and no `yes`; never discard a window, entry, schedule, focus, WIP, or
history. Accept one supported route atomically, then repeat from active-stale
and archived Plan origins and verify their existing origin consequence.

Choose an incapable existing parent in UX-S52. Resolve its finite/open
behavior, then exercise UX-S58 with equal and unequal Domain sets. Require the
parent behavior block first, child movement second, and Domain facts last;
change Domains only in the unequal variant. Traverse UX-S59 fully, reject back
to the exact parent query, reverse into the nearest builder, and stale both
subjects independently before acceptance. Cover a focused/WIP parent, an
already-decomposed parent, and a pending scope-closure review; proceed only
where the all-pairs matrix supplies every reconciliation and disclose every
focus/review consequence. Accept one supported two-subject action and prove
that neither Nature nor composition can become visible alone. Verify atomic
UX-198 `batch` compensation and one conflicting later structure edit.

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

For UX-S53, first choose an eligible parent with exactly the same direct Domain
set. Verify the compact From/To body, absence of Domain contrast and
`change Domains`, and conditional rendering of both quiet information lines.
Exercise no, every reverse gesture, and UX-S54 through direct yes, direct no,
read-only consequence inspection, `/show`, and repeated uncertainty; none may
move or record evidence before UX-S53 yes. Exercise Escape, Left Arrow, and
empty-buffer Backspace from both UX-S54 questions and require exact UX-S53
restoration. Make the target stale before one acceptance and require
UX-029..031 recovery. On separate fixed-state replays,
cover an empty sibling set, a nonempty set fully resolved by reusable evidence,
and a genuinely unresolved first midpoint comparison. The first two go
directly to UX-S38; the last enters ordinary uninterrupted insertion, then
reaches the same receipt on resolution or exit without a per-answer result or
draw. Verify the move and valid provisional position are atomic, old-scope
comparisons become inactive history, subtree order and direct Domains remain,
and any scope-review consequence is derived rather than silently completed.
Move a Domained Brick to root through the compact variant, and treat root while
already at root as the same event-free current-parent no-op. From the receipt,
reach context editing through `[u]pdate something else` then `[c]ontext` in two
keypresses. Powered-up and Skill may annotate the selector but must preserve
the preview, actions, absence of default, and commit boundary. Verify atomic
UX-198 `structure` plus `order_evidence` compensation.

For Nature/behavior, first select the current Nature in UX-S46 and prove an
event-free no-op. Traverse the full mechanical discovery route over the
existing Brick, reject its result, and verify no classification evidence was
recorded. Then reclassify `#tm "Take medication"` from `habit` to
`recurring_obligation`: collect the required schedule, render UX-S47, preserve
identity, importance, Domains, description, and all typed habit outcomes; stop
future habit windows and streak extension without rewriting history; and
release only future obligation occurrences after acceptance. Reject and edit
the preview on separate runs. Repeat with one attributed assisted Nature and
reject it back to exact dumb UX-S46. Generate all 81 MOD-077 source-to-target
pairs and mechanically derive preserved, removed, and added capabilities.
Exercise UX-NAT01 fixtures for a project with children, checklist with entries,
repeatable with a pending return, obligation with open occurrences, scheduled
commitment with an active interval, and focused/WIP Work. Every incompatible
fact must obtain WRK-122's explicit resolution or block confirmation without
silent conversion; then replay undo both before and after one intervening
conflicting action.

### SCN-LC-001 — Parent lifecycle, merge, and supersession

Build one finite tree containing active, done, archived, superseded, merged,
missed, and cancelled direct children, an internal Dependency, one inbound Dependency from
outside, an active Wait, disjoint and overlapping Delegations, pending and
dispatched effects, two descriptions, recurrence history, and conflicting
source baselines. Archive its parent through UX-LC00 on independent replays.
For `this Brick only`, verify visible one-level movement of every direct child
as one provisional run with internal subtrees and relative order preserved.
For `entire subtree`, preserve exact terminal descendants while archiving
active descendants. Traverse every UX-LC05 gate, reject once without partial
mutation, then accept and verify focus/WIP, Wait, Delegation, effect, recurring,
and cross-boundary Dependency outcomes. Dry-run must render the same preview.

Remove or terminally resolve every active child in another replay. Draw
UX-LC04 and verify separate state counts, no default, outcome inspection, add,
skip, and explicit parent completion. Restoring one child before acceptance
must replace the stale review. Completion must never cascade from the child
states.

Create two durable duplicate Bricks and traverse UX-LC01. Keep them separate
once, supersede once, and merge once. For merge, choose each survivor on
separate fixed-state replays and exercise every MOD-086 matrix row: parent and
Nature conflict, sibling evidence, Domains, descriptions and other RawLinks,
Dependency cycle, equal/different Waits, dates, recurrence state, overlapping
Delegation, focus/WIP, effects, annotations, occurrences, and SourceBindings.
Verify one `merged` loser, no silent handle redirect, original event subjects,
one atomic result, and undo before and after an intervening conflict. For
supersede, use both an existing and newly drafted replacement, move children
to it and one level up, and prove MOD-087 transfers nothing by resemblance.
Pair each dumb route with an attributed assisted suggestion and reject it back
to the identical baseline.

### SCN-CMD-001 — One public command language

Enumerate the [canonical command catalog](../command-catalog.md) and prove
that every registered slash command has a grammar entry, valid-state palette
route, typed unavailable-state error, CLI semantic mapping, and help text.
Prove no other public command appears in generated help or completion. Try all
explicitly rejected spellings and verify a bounded educational suggestion,
unchanged interaction revision, unchanged random cursor, and no event.

Open `/list`, inspect both importance and Focus branches under full, Brick,
and Domain scope, page them twice, return, and prove no draw or mutation.
Compare `lant tick` against the automatic tick at the same injected instant;
their temporal events match while explicit tick produces no opportunity.
Export every standard ReadOnlyExporter to stdout and to a new file, then test
an existing path, symlink, missing parent, nonregular target, exporter failure,
and interrupted write. No Pack sees a path; failure leaves no partial target;
success reports bytes and digest. Finally start `lant --power-up` with valid,
invalid, silent, oversized, and malformed stdin/stdout helpers and prove that
no `lant repl` compatibility spelling exists.

### SCN-EXT-001 — Import and source deletion

Run UX-IMP00..IMP02 against fixed fake Microsoft To Do and Google Tasks
providers. Exercise snapshot, synchronize, and migrate; completed-item opt-in;
source-list shelf suggestions; duplicate suspicion; stale preflight; locked
credentials; partial attachment failure; and repeated idempotent import. Prove
that every accepted object becomes Raw before any adoption and that source
completion, disappearance, and list structure create no local outcome,
Domain, or importance evidence.

Migrate Microsoft To Do with `--erase-after-import`. Verify local counts and
digests before UX-A01 can appear, reject cleanup once, approve its exact item
set once, interrupt it, fail one deletion, and resume. Prove one itemwise
receipt, no duplicate deletion, no rollback, no false completion, and a
separate empty-list approval. Request the flag for GitHub Issues, Apple
Reminders, Notesnook, and Evernote and require `unsupported` before mutation.
Import Apple Shortcut JSON, Notesnook Markdown ZIP, and Evernote ENEX twice and
prove file-digest identity and lazy Raw triage.

### SCN-EFF-001 — External-effect truth

For every DAT-068 purpose, render UX-A01 with its exact target, account,
payload summary, and consequence. Reject, defer where legal, edit one message,
approve, crash after durable dispatch intent, and return through UX-EFX00.
Replay idempotent retry, non-idempotent unknown outcome, read-only provider
reconciliation, human external verification, terminal failure, and stop.
Assert that no Pack invocation, dry-run, replay, undo, edit, stale approval, or
batch receipt dispatches a new effect or transfers approval across revisions.

### SCN-CAL-001 — Calendar adoption and reconciliation

Against a fixed fake Google Calendar, allowlist one calendar in observe-only
mode. Import a flight, isolated meeting, recurring meeting, recurring swim,
all-day deadline, unsupported RRULE, one moved occurrence, one cancelled
occurrence, and one event that later becomes inaccessible. Traverse UX-CAL00
to adopt this occurrence, exact scheduled series, atomic recurring obligation,
habit, civil-day Work, and preserve Raw. Verify exact zones, one series
importance slot, occurrence identities, hard scheduled precedence, exception
scope, and no inferred attendance or completion.

Traverse UX-CAL01 for remote reschedule, cancellation, deletion, and access
loss. Keep local, accept source, detach, and recreate on independent replays.
Enable reviewed write-back for only that calendar, then create, update, and
cancel through separate UX-A01 effects with failure and divergence recovery.
Prove observe-only never asks for write scope, attendees never become
ExternalEntities, private fields stay out of default assisted projections, and
rejection of every assisted proposal returns to the identical dumb route.

### SCN-UIA-001 — Local web mirror

Start `/web` on loopback, replay accepted Feed, Focus, skip, import, Calendar,
and effect envelopes, and compare wording, action order, revisions, stale
recovery, and approval boundaries with the dumb REPL. Reject a replayed browser
action after host restart, verify the session token never enters history or
Pack state, and prove that non-loopback binding is unsupported in 1.0.

### SCN-PACK-001 — Reproducible Pack trust and lifecycle

Build the same fixture Pack twice and require byte-identical `.lantpack` and
SHA-256 digests. Mutate path order, timestamp, extra field, duplicate path,
Unicode-colliding path, manifest byte, payload byte, signature, declared
permission, oversize input, and trailing archive data independently; every
noncanonical or unverifiable candidate must fail before extraction or Lua.

Traverse UX-PACK00 for built-in, verified official, trusted community,
untrusted community, unsigned, invalid, and revoked fixtures. Trust a community
key and prove it returns to an unapproved install. Traverse UX-PACK01 with
component, permission, configuration, and binding changes; reject once and
accept one exact plan while retaining the old archive side by side. Exercise
expired catalog, explicit refresh, rollback catalog, root transition,
equivocation, known revocation, UX-PACK02, removal with active bindings, and
garbage collection. Prove no background network/update, no Pack dependency,
no canonical-data deletion, no replay execution, and no assisted approval.

### SCN-MIG-001 — Verified v0.1 projection and cutover

Create one signed-v0.1 fixture containing every stage, kind, atomicity value,
skip reason, Party kind, SourceLink state, description revision, parent/part,
Dependency, before/after comparison, Wait state, Delegation state, generic
effect state, WIP transition, merge, supersession, and shipped legacy upcast.
Include a second fixture with malformed lines, an unknown version, duplicate
incompatible IDs, a context collision, relationship cycle, and irreconcilable
lineage. Hash both sources before every run.

Run the harmless command default and UX-MIG00. Verify the four mapping classes,
exact old-to-new dispositions, provisional sibling position without importance
evidence, conservative skip/Party/Nature handling, Description-as-Raw,
SourceBinding pause, inert old effects, and no write to source or target. The
invalid fixture must expose finite typed blockers and withhold build. Exercise
one repair, prove that it changes the plan hash, and reject one assisted repair
back to the identical dumb screen.

Build the valid plan, interrupt before and after identity allocation, retry,
and prove stable UUIDv7 mapping, handle suffixes, candidate isolation, embedded
archive hash, full zero-state replay, and UX-MIG01. Change the source and target
independently and require stale-plan failure. Traverse UX-MIG02, back out once,
then cut over once and verify atomic target switch, retained prior-target
backup, unchanged v0 bytes, complete MigrationRecord, no adapter invocation,
and no `/undo` claim. Repeat into an existing v1 dataset with equal UUID
lineage, conflicting equal UUID, and mnemonic-handle collision to exercise
`MIG-023`. Provider cleanup, if requested afterward, must begin a new UX-A01
effect and cannot reuse migration consent.

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

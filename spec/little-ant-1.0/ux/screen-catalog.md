# Canonical screen catalog

These are normative English reference compositions. Terminal width may wrap
long paths, but renderers preserve the content order and action order.

## Shared composition

```text
<primary subject or complete preview>

<concrete question>

<canonical actions>

<secondary command escape>

────────────────────────────────────────
<at most one warning and overflow count>
<optional subject-specific facts>
. <parent Brick or <root>>
  <Domain path or <no Domain>>
. <most useful temporal fact or operational workday>
          Now: <civil date and local time>
. <active bricks>, <Raws awaiting review>, <unresolved reviews>
  mode: <mode>, focus: <Brick handle or idle>
```

Warnings and subject-specific facts are omitted when absent. The footer itself
always retains its three two-line blocks. Markdown code blocks show the
monochrome structure: a capable terminal applies UX-070..073, including the
dim footer and divider, normal-intensity semantic footer values, dim shortcut
brackets, bold cyan shortcut characters, and reverse video for command-palette
selection. Styled and plain renderings occupy the same display-cell columns.

## UX-R00 — Dumb REPL frame

The REPL opens by restoring or obtaining `next`, not by waiting for a command.
The stacked footer follows the divider rather than occupying the top of the
screen:

```text
Work:

#rrsr "Review Rock Splitter rules"

Focus?

[y]es    [s]kip    [?] I don't know
[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

The automatically served envelope, secondary-command escape, contextual facts,
and stacked footer are all part of REPL UX. `[?] I don't know` belongs to
the current Focus decision, while `[/] more...` opens UX-M01. Adaptive or
narrow-terminal rendering may fold regions but cannot test only the inner
envelope and call that a REPL simulation.

Powered-up mode reuses the frame and changes only:

```text
  mode: powered up, by: /bin/claude-fast.sh, focus: idle
```

plus any explicitly attributed proposals that passed the startup handshake.

## UX-M01 — Contextual command palette

Pressing `/` from UX-R00 suspends, but does not cancel, its pending Focus
interaction:

```text
More:

› /

/done       Mark #rrsr "Review Rock Splitter rules" as done
/feed       Feed Little Ant
/show       Inspect #rrsr "Review Rock Splitter rules"
/history    Open interaction history

Type to filter available commands.
↑/↓ select · Enter run · Esc back

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

Only currently valid commands participate in search. The initial suggestions
are contextual and replay-deterministic. Descriptions expose the current
target rather than relying on a hidden argument. Escape restores UX-R00
unchanged. `/show` returns to it; `/done` resolves it; a completed `/feed`
Raw commit revalidates it before anything may act on the old proposal.

## UX-RF01 — Typed reference autocomplete

Typing `#` in a reference-capable input opens a typed search rather than
requiring a memorized identifier:

```text
Choose a Brick:

› #rs

  #rs "Rock Splitter"
  #rs2 "Reason Season"
  New Brick...

↑/↓ select · Enter choose · Esc back
```

The query matches handles and canonical titles. `New Brick...` is absent when
the pending interaction permits only an existing target. Typing `+` opens the
equivalent Raw search:

```text
Choose raw material:

› +milk

  +milk "milk"
  +aen "API error notes"
  New raw material...

↑/↓ select · Enter choose · Esc back
```

It searches the Raw handle, original and current normalized content, source
label, and filename. `New raw material...` is absent when creation is invalid
in the suspended interaction; when selected, it opens ordinary Feed and
returns the resulting `+` reference rather than creating Raw through another
path. Typing `@` opens the equivalent person-or-company search from UX-075;
its creation row is always `New person or company...`. UUIDv7 values are
available in technical projections but never appear in these ordinary
selectors.

## UX-RF02 — Dataset handle-conflict preview

A v1 dataset merge preserves internal identity and previews any public
reference change before mutation:

```text
Reference handle conflict:

#rs "Rock Splitter"
#rs "Reason Season"

Proposed remapping:
#rs "Rock Splitter"  → unchanged
#rs "Reason Season"  → #rs2

Internal identities will not change.

Continue?

[y]es   [n]o   [?] I don't know
```

The preview is deterministic for the same two inputs. Confirmation records an
inspectable mapping report and creates no alias. If the datasets contain the
same UUID with incompatible lineage, this confirmation is replaced by a typed
identity-conflict result with a concrete recovery path.

## UX-RF03 — Global search

Invoking `/search` or pressing `Ctrl-F` suspends the exact current interaction
and opens one type-visible dataset search:

```text
Search Little Ant:

› milk

  Work       #bg "Buy groceries"
  List item  Milk · within #bg "Buy groceries"
  Raw        "milk" · Inbox
  Shelf      "Cooking notes"

↑/↓ select · Enter inspect · Esc back

────────────────────────────────────────
. <root>
  Personal › Housekeeping
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

Result kinds are human labels, not serialized constructor names. Results may
include Bricks, Raw, ListEntries, people or companies, Domains, and RawShelves.
Selecting one opens read-only inspection; backing out restores the search and
then the exact suspended screen, draft, cursor, and checkpoints. This global
route never chooses a value for another pending field. A contextual selector,
such as Raw destination search, retains its narrower result type and returns a
value to its owning flow. Empty results remain inside this screen with a
concise recovery to edit or clear the query; they never fall through to
creation. `/history` remains the event-search route.

## UX-R01 — Civil clock and operational day

At 02:00 on Tuesday, the stacked footer keeps the real civil date. If the
configured workday began at 06:00, it exposes the differing operational label
instead of silently displaying Monday as though it were the calendar date:

```text
. <root>
  <no Domain>
. Workday: Mon, Aug 3
          Now: Tue, Aug 4, 02:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

A habit opportunity still belonging to Monday may add:

```text
. Habit day: Monday · closes Tue, Aug 4 at 04:00 America/Montevideo (UTC-03)
          Now: Tue, Aug 4, 02:00
```

An exact event remains exact and zoned regardless of either operational
boundary:

```text
✈️ Tue, Aug 4 · 02:30 · America/Sao_Paulo (UTC-03)
```

## UX-R02 — JSONL loading splash

During an observable interactive cold replay, the REPL briefly occupies the
terminal with this transient factory composition:

```text
       /\/\
     __\_\  _..._
    ("  )  (_..._)
     ^^      // \\

        L I T T L E    A N T

Loading 000000...
```

The counter advances in place for each event successfully decoded and folded.
It is padded to at least six digits and grows rather than wrapping after
`999999`. If a total is already known without an extra scan, a renderer may add
it after the processed count; an unknown total is never guessed. The splash
clears before UX-R00, a restored-current-focus screen, or a typed startup error
is rendered. It has no minimum duration, so small datasets do not incur a
ceremonial delay and may never display a perceptible frame. Redirected or
non-interactive commands emit neither the art nor cursor-control sequences.

## UX-F01 — Focus

```text
Work:

#wtms "Write the migration specification"

Focus?

[y]es    [s]kip    [?] I don't know
[/] more...

────────────────────────────────────────
⚠️ #smr "Submit migration report" · deadline in 2h · +2 warnings
. #rlav2 "Recover Little Ant v1"
  Personal › Little Ant
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

`yes` focuses and starts WIP. `skip` opens UX-S01. `?` enters UX-F12 without
consuming another draw. Direct completion remains available as `/done` in
UX-M01. Pressing unbound `n` gives the educational UX-062 result and restores
this same opportunity without mutation. This exact composition also serves an
undecomposed `project`; its Nature alone never inserts a structural preflight.

## UX-F02 — Cross-Domain focus

```text
Work:

#bg "Buy groceries"

Focus?

[y]es    [s]kip    [?] I don't know
[/] more...

────────────────────────────────────────
. <root>
  Personal › Housekeeping (from Orbit › R&D › Rock Splitter)
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

There is no preliminary `Switch Domain?`. `yes` starts focus and changes the
active Domain atomically; `skip` and palette actions that do not focus
preserve it.

## UX-F03 — Focus reached through blockers

```text
Work:

#dtimc "Define the importance-maintenance contract"

Focus?

[y]es    [s]kip    [?] I don't know
[/] more...

────────────────────────────────────────
🚧 reached through #rlav "Release Little Ant v1"
   → blocked by #rio "Restore importance ordering"
   → blocked by this Brick
. #rlav2 "Recover Little Ant v1"
  Personal › Little Ant
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

Long paths may fold visually, but every cited Brick retains its complete
compact label. `?` enters UX-F12; its UX-F13 explanation shows the entire
selected path, alternatives at branching nodes, and recorded probabilities
without redrawing.

## UX-F12 — Guided Focus decision

Question mark on an ordinary proposal begins with the work itself:

```text
#wtms "Write the migration specification"

Do you understand what this Brick asks you to do?

[y]es    [n]o    [?] I don't know
[/] more...

────────────────────────────────────────
. #rlav2 "Recover Little Ant v1"
  Personal › Little Ant
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

Successive screens ask one FOC-048 Q0..Q4 question with the same proposal and
footer. Q1 `yes` opens read-only `/show`; after inspection, an explicit `no`
reuses UX-S34 to confirm `vague`. Q0, Q2, and Q4 may route uncertainty to the
same recovery as `no` without turning it into negative evidence. Reverse
navigation restores the preceding question and, from Q0, UX-F01, UX-F02, or
UX-F03 exactly.

## UX-F13 — Forecast explanation during Focus consent

Q3 `yes` renders the recorded selection rather than drawing again:

```text
Why this appeared:

#wtms "Write the migration specification"

Selected by the weighted focus forecast.

Strongest signal:
importance within #rlav2 "Recover Little Ant v1"

Additional signals:
same active Domain
unfocused for 9 days
no active cooldown

Selection:
1 of 18 admitted Bricks
replay-deterministic draw

[c]ontinue    [b]ack    [?] I don't know
[/] more...

────────────────────────────────────────
. #rlav2 "Recover Little Ant v1"
  Personal › Little Ant
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

The displayed values are illustrative renderings of exact FOC-049 facts, not
a fixed universal signal list. A cross-Domain result includes both paths; a
blocker redirect includes the complete chosen chain and unchosen branch
alternatives. Continue reaches Q4, back restores Q2, and uncertainty remains
open under `OPEN-UX-004` for its dedicated explanation tree. None consumes or
recomputes the draw.

## UX-F14 — Final Focus consent after assistance

After sufficient context and optional forecast inspection:

```text
Work:

#wtms "Write the migration specification"

Start focusing this Brick?

[y]es    [n]o    [?] I don't know
[/] more...

────────────────────────────────────────
. #rlav2 "Recover Little Ant v1"
  Personal › Little Ant
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

`yes` accepts the original proposal and starts Focus. `no` and uncertainty
both enter UX-S33 without recording a skip or symptom. If `/next` produced
this proposal while another Brick remained current, every uncommitted route
preserves that Focus; only this final `yes` switches it.

## UX-F04 — Current focus resting state

Pressing `y` on UX-R00 starts the Brick immediately and does not draw another
opportunity:

```text
Current focus:

#rrsr "Review Rock Splitter rules"

💪 Nice! Roll up your sleeves and give it a go.
Come back when you're done—or when something gets in the way. 😌

[d]one   [s]kip   [/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

The phrase is one `focus_started` entry from the 16-phrase factory catalog.
Rendering this interaction again does not choose another phrase. Powered-up
and Skill surfaces may apply UX-065 without changing anything else. The
opening UX-R00 intentionally has no personality line: Focus remains its single
visual decision. The palette exposes only commands valid for the current
focus; their final public names remain under `OPEN-WRK-001`.

## UX-F05 — Sober current-focus continuation

Closing and reopening the REPL five minutes after UX-F04 resumes the focus
without replaying its transition message:

```text
Current focus:

#rrsr "Review Rock Splitter rules"

[d]one   [s]kip   [/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:05
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

This continuation creates no event, performs no draw, and selects no
microcopy. Before the configured stale-focus boundary, it does not ask
`Still working on this?`. At or after that boundary, the same current-focus
continuation renders UX-F09; it never becomes a lottery opportunity.

## UX-F09 — Stale current-focus check-in

At the first safe interaction boundary after the configured stale-focus
threshold, the current continuation renders:

```text
Current focus:

#rrsr "Review Rock Splitter rules"

Still working on this?

[y]es    [s]kip    [?] I don't know    [d]one
[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Last activity: Sun, Aug 2, 22:14
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

`Last activity` is the latest explicit focus start, resume, or check-in; it
does not claim continuous work or observed effort. `yes` records one
replayable focus check-in and returns to UX-F05 without opening another focus
interval or drawing. `skip` opens UX-S01 and records nothing until a reaction
is accepted; `done` follows UX-F07; and `?` preserves this continuation. No
personality line competes with the check-in. Closing the REPL preserves the
same pending continuation. A non-current WIP review is a different,
ordinary-lottery route rendered by UX-F10.

## UX-F10 — Non-current WIP review

When the ordinary lottery selects review of a WIP that is not current:

```text
Review:

#rrsr "Review Rock Splitter rules"

This Brick is still in progress.

What should happen?

[r]esume    [s]kip    [?] I don't know
[d]one      return to [i]dle
[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Last focused: Sun, Aug 2, 22:14
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

`resume` starts a new focus interval and makes this Brick current. `skip`
defers only the selected review and leaves the Brick WIP; it does not open the
served-work symptom screen. `done` completes directly. `return to idle`
removes WIP without implying completion, failure, or deferment. The palette
may expose `archive`, `supersede`, history, and inspection without crowding the
ordinary choice. No action is selected merely by rendering the screen.

## UX-F11 — Scope-closure review

When every tracked child of an active finite parent is done and the ordinary
lottery selects its closure review:

```text
Review:

#ctpe "Carry this enormous rock"

All 3 tracked parts are done.

What should happen?

[d]one    [a]dd more work
[s]kip    [?] I don't know
[/] more...

────────────────────────────────────────
. <root>
  Personal › Housekeeping
. Last child done: Mon, Aug 3, 08:52
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

`done` completes the parent directly. `add more work` opens Feed with this
parent already resolved as the proposed owner; nothing changes until a new
child is confirmed and locally inserted. `skip` defers only this review and
never returns the parent as Work. `?` may inspect child history and completion
context. Reopening a child, `archive`, and `supersede` remain contextual-palette
routes. This composition is shared by every decomposed finite Brick and never
branches merely because its Nature is `project`.

## UX-F07 — Immediate focused completion

Pressing `d` on UX-F04 or UX-F05 does not open a confirmation:

```text
Done:

#rrsr "Review Rock Splitter rules"

🎉 Nice work. That Brick is in place.

[n]ext   [/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:32
. 17 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

The phrase is one `work_completed` entry from the 16-phrase factory catalog.
The contextual palette makes `/undo` available against the typed completion
event, and `Left Arrow` opens UX-U01 because no provisional backward
checkpoint remains. The REPL does not draw automatically from this result.
Pressing `n` invokes the ordinary canonical `next` pipeline; closing the REPL
instead leaves focus idle, and the next startup follows UX-046.

## UX-F08 — Repeatable Work offer

When a `repeatable_run` of `#rtfea` returns after an earlier completed
execution, it keeps the ordinary Focus composition:

```text
Work:

#rtfea "Read the focus-engine article"

Focus?

[y]es    [s]kip    [?] I don't know
[/] more...

────────────────────────────────────────
. <root>
  Learning
. Last completed: Tue, Feb 3, 2026
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

`yes` starts another execution of the same Brick identity; it creates no
occurrence Brick, replacement, or importance insertion. `skip` opens UX-S01;
final deferral follows `WRK-062` and creates no missed window, overdue
obligation, or terminal outcome. `?` may reveal execution history, source
material, and the recorded return rule without changing the draw. The
secondary history row does not rename the primary question or imply urgency.
A completion count may later share that row under UX-079, but a repeatable
Brick never renders invented missed cells. The completion/return/retire
screens remain the next UX decisions.

## UX-U01 — Contextual undo preview

Pressing `Left Arrow` after local backward navigation is exhausted does not
silently cross the commit boundary:

```text
Undo the last recorded action?

✅ Completed:
#rrsr "Review Rock Splitter rules"

[y]es   [n]o   [?] I don't know

[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:32
. 17 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

The preview identifies the typed action and its subject. `yes` invokes the
same semantic compensation as `/undo`; it restores the prior Brick and focus
state when preconditions still hold. `no`, Escape, or Backspace restores the
screen from which the preview opened without mutation. `?` explains the
projected changes and then restores this confirmation. If there is no eligible
action, no confirmation is fabricated.

## UX-U02 — Contextual redo preview

After UX-U01 is confirmed and no local forward checkpoint remains, pressing
`Right Arrow` offers:

```text
Redo the last undone action?

✅ Complete:
#rrsr "Review Rock Splitter rules"

[y]es   [n]o   [?] I don't know

[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:32
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

`yes` invokes the same checked reapplication as `/redo`. The current screen
and state remain unchanged until confirmation. An invalidated redo returns a
typed conflict rather than approximating the old action. A new branch or
committed action discards any incompatible redo chain.

## UX-F06 — Paused focus result

Selecting `/pause` from a current-focus palette commits immediately:

```text
Paused:

#rrsr "Review Rock Splitter rules"

This Brick remains in progress.

[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:05
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

The completed focus interval is history, but there is no `paused` Brick state,
skip evidence, cooldown, Domain change, personality phrase, or automatic
draw. The contextual palette remains anchored to the displayed WIP Brick.

## UX-C01 — Importance comparison

The proposition identifies the interaction by itself, so no semantic or
mechanism-oriented heading precedes it:

```text
Is

#ltlp "Launch the landing page"

      more important than

#ipc "Interview prospective customers"
?

*[m]ore important   [l]ess important   [s]kip   [?] I don't know

────────────────────────────────────────
Suggestion: /bin/claude-fast.sh · importance insertion
. #rtnw "Release the new website"
  <no Domain>
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: powered up, by: /bin/claude-fast.sh, focus: idle
```

The `*` appears only when evidence supports that default. `more important`
records the displayed first Brick above the second; `less important` records
the reverse strict relation. Neither means equality.

## UX-S01 — Served-work symptom

```text
#rrsr "Review Rock Splitter rules"

What's getting in the way?

💭 [v]ague    🧗 [h]ard     🏔️ bi[g]
🚧 [b]locked or waiting
🥱 [t]ired    😐 bo[r]ed    😨 [f]ear
⬇️ [l]ess important    🕰️ o[u]t of date
🧩 [o]ther
❓ [?] I don't know

Already finished?

✅ [d]one

[/] more...

────────────────────────────────────────
⚠️ #rfi "Review fraud incident" · deadline tomorrow
served after 9 days · active Domain unchanged
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

Selecting a symptom opens its separate reaction screen without recording
evidence. Reverse navigation under UX-019 from a reaction restores this exact
symptom screen; the same gestures here restore the exact Focus screen. Only
the final reaction commits the symptom and reaction together. An explicit
`skip anyway` reaction commits the symptom, cooldown, and no additional
remediation. This active diagnostic screen is sober: personality microcopy is
reserved for the committed `skip_acknowledged` result. Each symptom retains
its own icon; related choices share a row separated by spacing rather than
slash punctuation. `less important` is the current served-work symptom, not a
permanent importance classification or a separate priority axis.

## UX-S02 — Blocked-or-waiting classification

Selecting `[b]locked or waiting` on UX-S01 opens this uncommitted
classification:

```text
#rrsr "Review Rock Splitter rules"

What needs to happen before you can continue?

🧱 another [t]ask must be completed
👤 someone must [r]espond
🗓️ wait [u]ntil a date or time
📍 be at a [l]ocation
🔔 an [e]vent or condition must occur
❓ [?] I don't know

Continue without identifying it?

⏭️ [s]kip anyway

[/] more...

────────────────────────────────────────
⚠️ #rfi "Review fraud incident" · deadline tomorrow
served after 9 days · active Domain unchanged
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

The choices describe the human situation, not storage primitives. `task`
opens UX-S02A; `respond` opens UX-S02B for any eligible ExternalEntity rather
than only a person; `until` gathers a timezone-aware instant for `not_before`;
`location` gathers a Place condition; and `event or condition` accepts
dumb-mode free text preserved as linked Raw before creating a `Wait`. A
request not yet made becomes an enabling Brick and Dependency, while an
already-made request becomes a Wait with a future review opportunity. Each
route previews its typed result before one atomic commit. `skip anyway`
records explicitly unclassified `blocked_or_waiting` evidence and cooldown
without inventing a blocker or Wait. `Escape`, empty-buffer `Backspace`, or
local `Left Arrow` returns to UX-S01 under UX-019. No personality microcopy
appears before a final reaction commits.

## UX-S02A — Brick prerequisite route

Selecting `[t]ask` on UX-S02 opens:

```text
#rrsr "Review Rock Splitter rules"

Does the prerequisite already exist?

🔎 [f]ind an existing Brick
🧱 [c]reate an enabling Brick
❓ [?] I don't know

[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

`find` opens an existing-Brick selector; `create` opens UX-S03 and its pending
Feed route for one enabling Brick. Completing either route commits the
selected or newly created prerequisite, Dependency, `blocked` evidence,
accepted reaction, and cooldown atomically. Cancelling either subflow restores
UX-S02A without a partial Brick, Dependency, or skip. Reverse navigation
returns to UX-S02.

## UX-S02B — Response target autocomplete

Selecting `someone must [r]espond` on UX-S02 opens one autocomplete input:

```text
#rrsr "Review Rock Splitter rules"

Whose response are you waiting for?

›

Type a name. Existing entities will appear as you type.

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

After typing `Alice`, the same screen may contain:

```text
Whose response are you waiting for?

› Alice

  @am "Alice Moreira"    person
  @as "Alice Support"    team
  New person or company...
```

The active result uses reverse video on a capable terminal. Up/Down changes
the active result, Enter selects it, and further typing refines the bounded
results. Existing and creation candidates are separate revisioned action IDs,
not duplicate-suspicion guesses. Selecting `New person or company...` opens
canonical typed creation and returns the created identity here; ordinary copy
does not expose the technical term ExternalEntity, and this screen does not
infer `person` from the text `Alice`. Names retain their declared spelling and
no English-writing tip is shown. Escape, Left Arrow, or Backspace while the
buffer is already empty returns to UX-S02 without recording a person or
company, Wait, skip, or cooldown. Selecting a target continues to the
request-status question; it still commits nothing.

## UX-S02C — Request status

Selecting `@am "Alice Moreira"` in UX-S02B opens:

```text
#rrsr "Review Rock Splitter rules"

Needs a response from:

@am "Alice Moreira"

Has the request already been made?

[y]es   [n]o   [?] I don't know

[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

This binary question records nothing. `yes` enters UX-W00 before activating a
Wait. `no` enters pending enabling-Brick input and previews the complete
Dependency-to-Wait handoff under WRK-050 before one atomic commit. `?` explains
the difference between an outstanding human action and an external response
without choosing. Reverse navigation restores UX-S02B with its target
selection and input draft.

## UX-W00 — Wait review opening

The first activation and every `wait longer` route use the same finite choice:

```text
#rrsr "Review Rock Splitter rules"

Waiting for:
@am "Alice Moreira"

When may we start checking again?

[t]omorrow      (Tue, Aug 4)
*three [d]ays   (Thu, Aug 6)
one [w]eek      (Mon, Aug 10)
[c]hoose...

[?] I don't know

[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

The factory dumb suggestion for a human response is three days. Each relative
option exposes its absolute local date; the committed value is a timezone-aware
`review_not_before` instant. `choose` opens a guided date/time selector without
free text. Historical evidence, powered-up mode, or the Skill may move `*` to
one of these same actions under UX-059 and explain why, but cannot replace the
finite dumb baseline with an invented duration. Crossing the chosen threshold
only admits a weighted review opportunity; it does not force an immediate
screen, create a deadline, or become overdue.

## UX-W01 — Open Wait review

At or after `review_not_before`, when a Wait review opportunity wins the
ordinary subject-first draw, it renders a review rather than `Focus?`:

```text
Review:

#rrsr "Review Rock Splitter rules"

Waiting for:
@am "Alice Moreira"

Waiting since Mon, Aug 3

What happened?

[r]esponse received    [w]ait longer
[f]ollow up             [c]hange what is blocking it
[s]kip                  [?] I don't know

[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Last review: Mon, Aug 3, 09:00
          Now: Fri, Aug 7, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

`response received` resolves only the Wait and returns the affected Brick to
the forecast when no other gate applies. `wait longer` enters review-policy
selection through UX-W00. `follow up` enters an enabling-Brick flow and
preserves the declared successor Wait. `change what is blocking it` returns to
UX-S02 and replaces the old gate only after an explicit atomic preview. `?`
explains and may expose linked evidence without recording an outcome. `skip`
leaves the Wait and `review_not_before` unchanged, records only the typed
review deferral, and applies the review's cooldown and future pressure. It is
not `wait longer` and does not open served-work symptom diagnosis. The Wait
itself is never cited as work, focused, importance-ordered, or completed.

## UX-S03 — Enabling-Brick input

Selecting `[c]reate` on UX-S02A opens ordinary pending Feed input:

```text
Create an enabling Brick for:

#rrsr "Review Rock Splitter rules"

›

Tip: write in English when possible.
Esc returns without recording anything.

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

Enter commits the entered text as source Raw and, because the user explicitly
chose an enabling Brick, continues the ordinary duplicate, Nature, optional
Template, and importance-insertion route without UX-T01. Rejecting that later
preview leaves the Raw in the Inbox but commits no partial Brick, Dependency,
symptom, or cooldown. Because an editor is active, Backspace deletes and Left
Arrow moves the cursor. The keypress that deletes the final character leaves
the empty editor open; another Backspace while already empty, or Escape,
returns to UX-S02A under UX-019.

## UX-S04 — Dumb enabling structure

After the contextual Raw-backed builder resolves the pending `#ratpl` proposal,
dumb mode applies FED-030:

```text
Enabling Brick:

#ratpl "Request access to production logs"

Suggested structure:

Within: #rs "Rock Splitter"
Domain: Orbit › R&D › Rock Splitter
Blocks: #rrsr "Review Rock Splitter rules"

Use this structure?

*[y]es    [n]o    [?] I don't know

────────────────────────────────────────
. <root>
  <no Domain>
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:03
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

`yes` accepts the structural suggestion and continues the still-pending
sibling importance insertion at the ordinary unresolved midpoint under
IMP-004; the Dependency never supplies an importance answer or comparator
anchor. `no` opens the canonical parent and Domain choices with the same draft
and blocked target preserved. `?` explains composition, Domain, Dependency,
and importance separately before restoring this confirmation. Reverse
navigation restores the preceding pending builder checkpoint. The source Raw
already exists after input submission, but no Brick, Dependency, symptom,
cooldown, or comparison is durable until the complete reaction succeeds
atomically.

Skill or powered-up mode may instead precede UX-S04 with one attributed
FED-031 proposal containing the same three visible structural fields. Its
`yes` enters the same canonical validation and insertion continuation; its
`no` enters UX-S04 with the dumb baseline unchanged. If assistance has no
stronger evidence, it renders UX-S04 rather than paraphrasing the baseline as
an AI judgment.

## UX-S05 — Blocked result

Completing the enabling-Brick route commits once and waits without drawing:

```text
Blocked for now:

#rrsr "Review Rock Splitter rules"

Blocked by:

#ratpl "Request access to production logs"

🐜 Even ants reroute sometimes.

[n]ext    [/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:07
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

The phrase is one replay-stable `skip_acknowledged` entry under UX-064. The
result neither starts the blocker nor performs a forecast draw. `[n]ext`
invokes the ordinary weighted pipeline; dependency pressure applies without
guaranteeing the blocker a win. The contextual palette exposes
`/focus-blocker`, whose visible target is `#ratpl`. That command bypasses the
forecast draw but still opens the ordinary `Focus?` proposal; it never starts
work silently. If the named blocker is itself blocked, the canonical N-step
dependency resolver supplies the actionable endpoint and complete `Why` path.
The public command is the single kebab-case token required by UX-074.

## UX-S06 — Big recovery

Selecting `bi[g]` on UX-S01 opens this uncommitted reaction:

```text
#ctpe "Carry this enormous rock"

What would help?

[b]reak it into parts
[c]ollect more context
[l]earn about the subject
[s]kip anyway
[?] I don't know

[/] more...

────────────────────────────────────────
. <root>
  Personal › Housekeeping
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:04
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

`break` enters pending part collection and the UX-B01 preview; no structure or
symptom exists before that final confirmation. `collect more context` and
`learn about the subject` each enter contextual Feed for one enabling Brick.
Their complete previews include ordinary Nature confirmation, local
importance insertion, and a Dependency into `#ctpe`; accepting one records
the `big` evidence and recovery atomically, while the Dependency prevents the
original work from being served. `skip anyway` records only `big` and its
cooldown. Uncertainty explains the distinction without choosing. Reverse
navigation restores UX-S01 exactly and commits nothing. Explicit `/break`
enters decomposition independently and therefore never fabricates `big`
evidence.

## UX-S07 — Tired recovery

Selecting `[t]ired` on UX-S01 opens this uncommitted reaction:

```text
#rrsr "Review Rock Splitter rules"

You're tired. What would help?

🪶 [e]asier work
🔀 [c]hange subject
🌙 [p]ause for now
⏭️ [s]kip anyway
❓ [?] I don't know

[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

The choices are recovery proposals rather than new symptoms. Selecting
`tired` alone records nothing; reverse navigation restores UX-S01 exactly.
`Easier work` follows UX-S08, `change subject` follows UX-S09, and `pause for
now` follows UX-S10. Only their declared empty and multi-Domain boundaries
remain in `OPEN-SKIP-001`.

## UX-S08 — Easier-work shortlist

Selecting `[e]asier work` on UX-S07 opens one bounded, uncommitted choice:

```text
#rrsr "Review Rock Splitter rules"

Which one feels easiest to tackle right now?

[1] #up "Update the project notes"
[2] #rei "Reply to Elena's invitation"
[3] #dwd "Draft the weekly digest"

[?] I don't know

[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

The core supplies exactly three candidates when at least three exist and shows
the one or two available candidates otherwise. They follow FOC-044: current
executability is required, the served Brick is excluded, same-Domain and
lower-effort evidence are favored, and missing effort retains positive
probability. A candidate from another Domain shows its Domain path as a quiet
indented line beneath its citation; identical paths are omitted. With no
candidate, UX-S08 is not rendered; the exact useful recovery remains
`OPEN-SKIP-001` and may not commit or fabricate anything.

Pressing a visible number accepts WRK-069 atomically and then opens the exact
candidate in the ordinary UX-F01 focus proposal. The candidate is not focused
until `yes`. The selection supplies strong contextual forecast evidence and
weak relative-effort evidence under IMP-038; it assigns neither hours nor an
EffortProfile class. `?` explains that distinction and returns. Escape,
empty-state Backspace, or Left Arrow restores UX-S07 with no symptom,
cooldown, evidence, focus change, or draw. Once a number has committed the
reaction, reverse navigation offers semantic undo under UX-019 rather than
silently traversing the mutation.

## UX-S09 — Positive change-subject target

Selecting `[c]hange subject` on UX-S07 or UX-S11 opens one uncommitted target
choice carrying its originating symptom:

```text
#rrsr "Review Rock Splitter rules"

What would you rather work on?

[o]rganize and review

Or choose a subject:

[1] Orbit › R&D › Field Operations
[2] Orbit › Platform
[3] Personal › Little Ant
[4] Personal › Housekeeping

[m]ore options...
[s]kip anyway
[?] I don't know

[/] menu...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

The positive question avoids asking the user to reason about what must be
excluded. `Organize and review` appears only when FOC-046 has an eligible
typed meta-opportunity and is visually separate from Domain choices. Every
Domain alternative spells its complete path because a subcontext may make
sense only within its ancestors and identical leaf names may exist in
different branches. The dumb screen has no default.

`More options` advances through deterministic pages of at most four target
Domains and records no rejection or preference. A target does not repeat
within the same pending interaction; reverse navigation restores the previous
page, and the action disappears when the pool is exhausted. `[/] menu...`
opens the ordinary UX-022 command palette. Only its label changes on this
screen so that `more` cannot mean both pagination and commands.

Selecting a number commits WRK-070 and immediately performs the one FOC-045
draw inside the chosen target. The resulting Brick receives ordinary
`Work:`/`Focus?` consent and is not started automatically. The source-side
fatigue branch is inferred from where the complete current and target paths
diverge; the target receives positive affinity. Both signals later decay with
positive probability elsewhere, while active Domain changes only after
accepted focus. `Organize and review` instead follows WRK-075: one restricted
meta-opportunity draw, then decaying interaction-family continuity, without a
persistent mode. `Skip anyway` records only the carried `tired` or `bored`
symptom and Brick cooldown. `?` explains these distinctions and returns.
Escape, empty-state Backspace, or Left Arrow restores the originating UX-S07,
UX-S11, or previous page without symptom, cooldown, signal, focus change,
active-Domain change, or draw. Multi-Domain, no-Domain, and no-target recovery
remain explicit release boundaries.

## UX-S10 — Tired-pause result

Choosing `[p]ause for now` on UX-S07 while its Brick is current commits
WRK-071 and renders:

```text
Taking a break:

#rrsr "Review Rock Splitter rules"

This Brick remains in progress.

🌿 Rest a little. The rock will still be here.

[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

The shown sentence is truthful only for a served current or already-WIP Brick.
For an unstarted proposal it becomes `This Brick was left for later.` If an
unrelated Brick remains current, the sentence becomes `Your current focus is
unchanged.` and the footer identifies that focus. These variants never claim
that unstarted work is WIP or that unrelated attention was cleared.

The illustrative line is one replay-stable `safe_end` personality phrase, not
domain evidence or a command. No `[n]ext` or `[r]esume` competes with the rest
result. `[/] more...` opens the ordinary contextual palette, which may contain
valid `/next`, `/resume`, `/feed`, `/history`, or `/exit` actions according to
current state. The REPL stays on this screen until the user acts or exits; the
core never closes a process, starts work, draws, or invents a paused Brick
state. Left Arrow after the committed result offers semantic undo rather than
returning across the mutation.

## UX-S11 — Bored recovery

Selecting `bo[r]ed` on UX-S01 opens this uncommitted reaction:

```text
#rrsr "Review Rock Splitter rules"

You're bored. What would help?

[c]hange subject
[m]ake it more interesting
[s]kip anyway
[?] I don't know

[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

`Change subject` opens UX-S09 carrying provisional `bored` evidence. `Make it
more interesting` opens UX-S12. `Skip anyway` commits only `bored` and the
served Brick's ordinary cooldown. `?` helps distinguish changing subject from
changing method without choosing. Reverse navigation restores UX-S01 exactly;
the screen has no default, mutation, or personality line.

## UX-S12 — Make the work more interesting

```text
#rrsr "Review Rock Splitter rules"

How could we make this more interesting?

⏱️ [t]ry a short sprint
🧩 [b]reak it into visible steps
🔧 [f]ind a better way
❓ [?] I don't know

[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

Short sprint opens UX-S15 and follows WRK-076..080. Break reuses UX-B00..B02;
accepted structure records `bored` plus recovery and uses its Dependency
instead of cooldown. Find opens UX-S13. Reverse navigation restores UX-S11
without mutation. The screen adds no engagement score or motivational advice.

## UX-S13 — Dumb better-way classification

```text
#rrsr "Review Rock Splitter rules"

How might the approach improve?

[a]utomate repetitive parts
[s]implify the process
[l]earn another method
[g]et help from someone
[?] I don't know

[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

Each direct choice deterministically constructs the matching FED-032 editable
draft without requiring free text or a model. `?` may ask the same bounded
mechanical distinctions and return; it cannot invent or accept a method.
Reverse navigation restores UX-S12 with no draft or evidence.

## UX-S14 — Better-way enabling preview

Choosing `simplify the process` for the example produces this complete preview:

```text
Do this first:

"Simplify: Review Rock Splitter rules"

Then return to:

#rrsr "Review Rock Splitter rules"

Behaves as: atomic task · review later

Create this enabling Brick?

[y]es   [e]dit   [n]o   [?] I don't know

[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

The draft has no handle because no Brick exists yet. The complete pending
structure also includes FED-030's visible sibling placement, effective Domain,
Dependency, and local provisional importance evidence; narrow surfaces may
place these in secondary context but may not hide them. `Yes` commits WRK-074
atomically and then uses the ordinary blocked-recovery result. `Edit` changes
title, Nature, placement, and prerequisite-versus-independent relation before
returning here; dumb title input repeats the quiet English reminder. `No`
discards the complete draft and restores UX-S12. Uncertainty explains the
proposal and returns. Assisted concrete proposals identify their source and
still use this preview.

## UX-S15 — Short-sprint duration

Choosing `try a short sprint` from UX-S12 opens the duration decision without
recording `bored` or starting focus:

```text
#rrsr "Review Rock Splitter rules"

How long would you like to give it?

 [1] 5 minutes   — just get started
 [2] 15 minutes  — a short attempt
*[3] 25 minutes  — a Pomodoro
 [c]ustom...

[?] I don't know

[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

`1`, `2`, and `3` choose their visible duration. `*` and Enter choose the
visible default; 25 minutes is the dumb factory default, not a hidden model
choice. A custom route is visible, but its exact bounded chooser remains an
explicit release boundary. Accepting a duration is focus consent and follows
WRK-078 without a second `Focus?` screen. Escape, Backspace, or Left Arrow
returns to UX-S12 without evidence or a timer.

## UX-S16 — Active short sprint

Immediately after accepting 25 minutes, the ordinary current-focus screen is:

```text
Current focus:

#rrsr "Review Rock Splitter rules"

[d]one   [s]kip   [/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Sprint: 24:37 remaining · ends Mon, Aug 3, 09:25
     Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

The countdown is a presentation of the canonical target instant, not a stream
of mutations. A capable interactive terminal updates only the temporal footer
cells. Static or noninteractive output instead shows `Sprint ends: Mon, Aug 3,
09:25`; it never emits ANSI animation. Ordinary focus commands remain valid.
An unfinished input or palette is not overwritten when the clock reaches
zero; UX-S17 appears at the next safe, revalidated interaction boundary.

## UX-S17 — Short-sprint time is up

```text
Sprint time is up:

#rrsr "Review Rock Splitter rules"

What would you like to do?

[c]ontinue       [a]nother sprint
[d]one           [p]ause
[?] I don't know

[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Sprint ended: Mon, Aug 3, 09:25
           Now: Mon, Aug 3, 09:25
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

Elapsed time leaves the Brick WIP and focused. Continue removes only the
timebox. Another sprint returns to UX-S15 with 25 minutes visibly selected in
this example. Done completes immediately; pause clears attention and retains
WIP. Uncertainty explains those consequences and returns. No branch interprets
the elapsed timer as completion, progress, observed effort, or failure.

## UX-S18 — Fear recovery

```text
#pmr "Present the migration risks"

You're worried about this. What would help?

🔬 [v]alidate the risk first
🪜 [m]ake a safer first move
🤝 [g]et support
⏭️ [s]kip anyway
❓ [?] I don't know

[/] more...

────────────────────────────────────────
. #rm "Recover the migration"
  Orbit › Platform › Migration
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #pmr
```

No option is a hidden default. Fear remains provisional until a final recovery
or explicit skip is accepted. The screen creates no risk score or psychological
classification. Reverse navigation restores UX-S01 without mutation.

## UX-S19 — Dumb risk-validation input

```text
#pmr "Present the migration risks"

What should be learned or tested first?

›

Tip: write in English when possible.

[/] more...

────────────────────────────────────────
. #rm "Recover the migration"
  Orbit › Platform › Migration
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #pmr
```

The dumb core asks for the missing content instead of fabricating a validation
method. Submitting `Test the migration with a small internal group` opens
UX-S21. Empty Backspace, Escape, or Left Arrow returns to UX-S18; ordinary
Backspace edits nonempty input.

## UX-S20 — Dumb safer-move input

```text
#pmr "Present the migration risks"

What would be a safer first move?

›

Tip: write in English when possible.

[/] more...

────────────────────────────────────────
. #rm "Recover the migration"
  Orbit › Platform › Migration
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #pmr
```

Submitting `Present the migration risks to Alice privately` opens UX-S21. The
navigation and editing rules are identical to UX-S19. This route proposes no
validation phase merely because its origin was fear.

## UX-S21 — Fear enabling-Brick preview

The validation example produces:

```text
Do this first:

"Test the migration with a small internal group"

Then return to:

#pmr "Present the migration risks"

Behaves as: atomic task · validation · review later

Create this enabling Brick?

[y]es   [e]dit   [n]o   [?] I don't know

[/] more...

────────────────────────────────────────
. #rm "Recover the migration"
  Orbit › Platform › Migration
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #pmr
```

The safer-move variant omits `validation` from `Behaves as`. Both previews also
carry FED-030's visible sibling placement, effective Domain, Dependency, and
local lazy importance evidence. The draft has no handle before acceptance.
Yes follows WRK-082; edit returns to the applicable input and then this full
preview; no restores UX-S18; uncertainty explains the structure and returns.

## UX-S22 — Support target

```text
#pmr "Present the migration risks"

Who could help?

› @

Type @ to find a person or company.

[/] more...

────────────────────────────────────────
. #rm "Recover the migration"
  Orbit › Platform › Migration
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #pmr
```

The typed autocomplete includes existing ExternalEntities and `New person or
company...`. Choosing the latter enters the ordinary ExternalEntity creation
preview and returns here after acceptance. Arbitrary text is not silently
promoted to an Entity. Reverse navigation restores UX-S18 without mutation.

## UX-S23 — Support form

After selecting Alice:

```text
#pmr "Present the migration risks"

How could @am "Alice Moreira" help?

[a]sk for advice
[w]ork together
[d]elegate this Brick
[?] I don't know

[/] more...

────────────────────────────────────────
. #rm "Recover the migration"
  Orbit › Platform › Migration
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #pmr
```

Advice enters the request-handoff preview with `Ask Alice Moreira for advice
about: Present the migration risks`; accepted request completion activates its
successor Wait. Work together previews `Arrange work with Alice Moreira on:
Present the migration risks` as an enabling Brick without inventing a meeting.
Delegate enters the existing Delegation preview. No choice is a default, and
no `fear` evidence is recorded before the resulting canonical preview is
accepted.

## UX-S24 — Vague recovery

```text
#rmr "Review the migration requirements"

This Brick is vague. What is missing?

🎯 [g]oal         — the intended result is unclear
📚 [i]nformation  — more context is needed
🧭 [f]irst step   — it is unclear how to begin
⏭️ [s]kip anyway
❓ [?] I don't know

[/] more...

────────────────────────────────────────
. #rm "Recover the migration"
  Orbit › Platform › Migration
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rmr
```

Goal changes descriptive content; information and first step may discover real
enabling work. The screen creates no Definition, clarification Brick, phase,
or uncertainty score. There is no default. Reverse navigation restores UX-S01
without mutation.

## UX-S25 — Dumb goal clarification

```text
#rmr "Review the migration requirements"

What result should this Brick produce?

›

Tip: write in English when possible.

[/] more...

────────────────────────────────────────
. #rm "Recover the migration"
  Orbit › Platform › Migration
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rmr
```

The answer remains uncommitted Raw text. Backspace edits a nonempty buffer;
Backspace on an empty buffer, Escape, or Left Arrow restores UX-S24. Submitting
nonblank text opens UX-S26.

## UX-S26 — Description clarification preview

After entering `Produce an approved list of migration requirements`:

```text
Clarify:

#rmr "Review the migration requirements"

Proposed Description clarification:

"Produce an approved list of migration requirements"

Apply this clarification?

[y]es   [e]dit   [n]o   [?] I don't know

[/] more...

────────────────────────────────────────
. #rm "Recover the migration"
  Orbit › Platform › Migration
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rmr
```

The preview describes the semantic Description change without exposing whether
the canonical Raw implementation revises, replaces, or relinks content; that
storage decision remains `OPEN-RAW-001`. Yes follows WRK-085. Edit returns to
UX-S25 with the text selected, no restores UX-S24, and uncertainty explains
that this is content rather than another Brick.

## UX-S27 — Find a first step

```text
#rmr "Review the migration requirements"

How should we find a first step?

[b]reak it into parts
[l]earn about the subject
[g]et help
[s]kip anyway
[?] I don't know

[/] more...

────────────────────────────────────────
. #rm "Recover the migration"
  Orbit › Platform › Migration
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rmr
```

Break reuses the complete decomposition route. Learn enters contextual Feed
for one enabling learning Brick. Help reuses UX-S22..S23 with `vague` carried
provisionally. Skip records only `vague` plus cooldown. Uncertainty explains
the three mechanisms and returns; reverse navigation restores UX-S24.

## UX-S28 — Hard recovery

```text
#cdd "Configure database replication"

This feels hard. What would help?

📚 [l]earn or practice first
🧩 [b]reak into smaller parts
🔧 [f]ind an easier approach
🤝 [g]et help
⏭️ [s]kip anyway
❓ [?] I don't know

[/] more...

────────────────────────────────────────
. #mdb "Migrate the database"
  Orbit › Platform › Database
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #cdd
```

The deliberately overlapping break action lets a user recover even when
`hard` was chosen where `big` might also have fit. Accepting that route records
`hard` plus `break into smaller parts`, not `big`. No choice is a default or an
effort class. Reverse navigation restores UX-S01 without mutation.

## UX-S29 — Dumb learning-or-practice input

```text
#cdd "Configure database replication"

What should be learned or practiced first?

›

Tip: write in English when possible.

[/] more...

────────────────────────────────────────
. #mdb "Migrate the database"
  Orbit › Platform › Database
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #cdd
```

Submitting a nonblank title commits source Raw and enters the explicit
contextual Work builder without UX-T01: Nature remains an explicit choice, and
the complete preview shows sibling placement, effective Domain, Dependency,
and local importance insertion. The dumb core does not
assume that practice is a habit or that learning is atomic. Empty Backspace,
Escape, or Left Arrow restores UX-S28 without mutation.

## UX-S30 — Less-important recovery

```text
#cdd "Configure database replication"

What should change?

⚖️ [o]rder it lower
🕒 [l]ater
🧭 [c]hange subject
⏭️ [s]kip anyway
❓ [?] I don't know

[/] more...

────────────────────────────────────────
. #mdb "Migrate the database"
  Orbit › Platform › Database
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #cdd
```

Order begins IMP-039's canonical lower-directed insertion but moves nothing
until a `more important` or `less important` answer is accepted. Later opens an
explicit absolute date and changes only `not_before`. Change subject reuses
the positive full-path Domain selector and one FOC-047 scoped draw without
source fatigue. Skip changes neither order, time, nor Domain. No option is a
default; uncertainty explains these three axes and returns.

## UX-S31 — Other explanation

```text
#cdd "Configure database replication"

What else is getting in the way?

›

Tip: write in English when possible.

[/] more...

────────────────────────────────────────
. #mdb "Migrate the database"
  Orbit › Platform › Database
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #cdd
```

The buffer is pending verbatim event evidence, not Raw or a custom symptom.
Backspace edits nonempty text; Backspace on an empty buffer, Escape, or Left
Arrow restores UX-S01. Nonblank submission opens UX-S32 without mutation.

## UX-S32 — Other skip confirmation

After entering `The office is too noisy`:

```text
#cdd "Configure database replication"

Skip this Brick for now because:

"The office is too noisy"

[y]es   [e]dit   [n]o   [?] I don't know

[/] more...

────────────────────────────────────────
. #mdb "Migrate the database"
  Orbit › Platform › Database
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #cdd
```

Yes follows WRK-093 and renders the ordinary skip acknowledgment. Edit returns
to UX-S31 with the complete text selected; no restores UX-S01; uncertainty
explains the verbatim evidence and returns. The dumb core infers no existing or
new symptom. Assisted categorization follows UX-129 and remains attributed,
rejectable, and uncommitted.

## UX-S33 — Guided symptom discovery

Question mark on UX-S01 begins with one mechanical split:

```text
#cdd "Configure database replication"

Must something outside this Brick happen before you can continue?

[y]es    [n]o    [?] I don't know

[/] more...

────────────────────────────────────────
. #mdb "Migrate the database"
  Orbit › Platform › Database
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #cdd
```

Successive answers traverse the exact Q0..Q8 tree in WRK-095. Each screen asks
only its current question with the same grammar. Question mark substitutes the
alternate probe in WRK-096 for that split without choosing a branch; repeated
uncertainty leaves the interaction pending. Escape, empty-buffer Backspace, or
Left Arrow restores the immediately preceding question, and doing so from Q0
restores UX-S01. No answer is durable evidence.

## UX-S34 — Discovered symptom confirmation

For a path that reaches `big`:

```text
#cdd "Configure database replication"

It sounds like the main obstacle is:

🏔️ big

Because independently tracked parts would make this Brick manageable.

Is this what is getting in the way?

*[y]es    [n]o    [?] I don't know

[/] more...

────────────────────────────────────────
. #mdb "Migrate the database"
  Orbit › Platform › Database
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #cdd
```

The label and reason change with the reached leaf. `yes`, `*`, or Enter opens
the existing reaction screen and records nothing; `other` opens UX-S31. `no`
restores UX-S01, uncertainty restarts UX-S33 at Q0, and reverse navigation
restores the decisive question. Assisted markings follow UX-133 and never
replace this confirmation.

## UX-S35 — Out-of-date recovery

```text
#rrsr "Review Rock Splitter rules"

What does "out of date" mean here?

🗄️ [a]rchive it
    It no longer seems worth pursuing; review that decision later.

🔁 [r]eplaced by newer Work
    Preserve the relationship by superseding it.

✏️ [u]pdate it
    The intention remains, but its content or structure is stale.

⏭️ [s]kip anyway
❓ [?] I don't know

[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Last focused: Sun, Aug 2, 22:14
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

No action is a default. Archive commits WRK-099 and then renders a concise
result with `/undo` in the palette; it does not apply ordinary cooldown.
Replacement and update remain uncommitted until their existing complete
preview is accepted. Skip records only `out_of_date` and cooldown. Question
mark distinguishes retirement, replacement, revision, and temporary deferral
through a bounded UX-016 tree. Escape, Backspace, or Left Arrow restores
UX-S01 without evidence.

## UX-S36 — Archived relevance review

```text
Review:

#rrsr "Review Rock Splitter rules"

Archived because: out of date
Archived: Mon, Aug 3, 09:04

What should happen now?

[k]eep archived
[r]estore it
[u]pdate and restore
[n]ewer Work replaced it
[s]kip
[?] I don't know

[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Archived: Mon, Aug 3, 09:04
       Now: Mon, Aug 17, 10:11
. 17 bricks, 7 raws, 4 reviews
  mode: dumb, focus: idle
```

The review is an ordinary weighted non-execution opportunity, not execution
of the archived Brick. Keep resolves this one automatic review without
creating another. Restore preserves identity and history, deterministically
places the Brick near its last valid sibling neighborhood, and marks that
placement for lazy importance review. Update and restore first previews an
edit to the same Brick. Newer Work enters explicit supersession. Skip changes
no lifecycle or lineage and leaves this marker unresolved with review
cooldown. Every mutation has its own preview; immediate semantic undo of the
original archive is not presented as restoration.

## UX-S37 — Semantic update hub

```text
Update:

#rrsr "Review Rock Splitter rules"

What do you want to update?

[m]eaning
    Title or description.

[b]ehavior
    What kind of Work this is: task, checklist, habit, or another Nature.

[p]lan
    Parts, prerequisites, waits, or delegation.

[t]iming
    When it may start, should happen, or repeat.

[c]ontext
    Domains, people or companies, and related Work.

[s]ource material
    Linked Raw material or external sources.

[v]iew everything
    Inspect the complete Brick without changing it.

[?] I don't know

[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Last focused: Sun, Aug 2, 22:14
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

This screen is reached directly through `/update #brick`, from active `update
it`, or from archived `update and restore`. It dispatches only to the closed
typed routes in WRK-101. `plan` is a UI route to parts, prerequisites, waits,
or delegation; it is not a Plan entity, phase, or classification axis. The
screen is not a form, schema browser, generic object editor, or domain event.
No option is a dumb default. View everything opens `/show` read-only and
returns here with the same pending interaction. Assistance may mark one option
and add an attributed reason, for example:

```text
*[s]ource material
    Linked Raw material or external sources.

Suggestion: the linked Microsoft document changed after this Brick was last reviewed.
```

The suggested branch and every other action remain unchanged. Exact edits
still require their typed branch preview. Reverse navigation returns to the
exact originating screen without evidence. A direct update records only each
accepted typed mutation. An active out-of-date entry records `out_of_date`
atomically with its first accepted mutation; an archived entry restores only
at that same boundary.

## UX-S38 — One accepted update

After an accepted title preview, the stable receipt is:

```text
Updated:

#rrsr "Review the current Rock Splitter rules"

Title:
"Review the old Rock Splitter rules"
→
"Review the current Rock Splitter rules"

Anything else?

[u]pdate something else
[r]eturn to Work

[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Updated: Mon, Aug 3, 09:06
      Now: Mon, Aug 3, 09:06
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

The changed fact block varies with the typed operation but always shows the
complete human-relevant before and after values. Update something else returns
to UX-S37. Return to Work follows UX-155 without focusing or drawing silently.
The first accepted active update records `out_of_date` in the same semantic
transaction; later updates in this update sequence do not repeat it. Every
receipt has its own `/undo`, and Left Arrow opens UX-U01 rather than crossing
the commit boundary as navigation.

## UX-S39 — Meaning choice

```text
Update meaning:

#rrsr "Review Rock Splitter rules"

What part of its meaning is stale?

[t]itle
    The short canonical name shown in lists and references.

[d]escription
    Longer context, intended result, and useful explanation.

[?] I don't know

[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Last focused: Sun, Aug 2, 22:14
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

Description is the human projection of an ordinary attached Raw under
MOD-056, not a Brick field. There is no `both`; completing either independent
change reaches UX-S38, where `update something else` can return here. No option
is a default. Reverse navigation restores UX-S37 without evidence.

## UX-S40 — Selected title editor

```text
Update title:

#rrsr "Review Rock Splitter rules"

› Review Rock Splitter rules

Tip: write in English when possible.

Enter review · Esc back

[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Last focused: Sun, Aug 2, 22:14
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

On entry, the complete current title is selected with the same accessible
treatment as UX-A02. Printable input or paste replaces it, Backspace or Delete
clears it, and an arrow collapses the selection without editing. Enter reviews
a changed nonblank draft through UX-S41; unchanged input produces no event and
keeps this editor. Escape restores UX-S39.

## UX-S41 — Title-change preview

```text
Change title?

From:
"Review Rock Splitter rules"

To:
"Review the current Rock Splitter rules"

Reference:
#rrsr · unchanged

[y]es    [e]dit    [n]o    [?] I don't know

[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Last focused: Sun, Aug 2, 22:14
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

Yes follows WRK-104 and reaches UX-S38. Edit returns to UX-S40 with the draft
selected; no discards it and returns to UX-S39. The UUID, handle, structural
and importance context, lifecycle, WIP, and focus do not change, and the old
title does not become an alias. Question mark explains those consequences and
restores this preview.

## UX-S42 — Description revision preview

```text
Update description?

Current:

"Review the rules that were deployed during the first Rock Splitter pilot."

Proposed:

"Review the rules currently deployed in production and document obsolete exceptions."

English normalization:
will need review after this change

[y]es    [e]dit    [n]o    [?] I don't know

[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Last focused: Sun, Aug 2, 22:14
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

The screen never exposes a Description object or technical Raw ID. Yes appends
the proposed original-text revision to the same ordinary Raw and reaches
UX-S38; when no `RawLink(role = description)` exists, it instead creates one
ordinary Raw and the link atomically. Edit returns to UX-S43 with the exact
draft; no discards it and restores UX-S39. The normalization warning is omitted when
none exists. If the Raw has other non-description consumers, a human-visible
`Also used by:` block lists each affected Brick, RawShelf, Domain, or other
projection before the actions.

## UX-S43 — Multiline description editor

```text
Update description:

#rrsr "Review Rock Splitter rules"

› Review the rules currently deployed in production.
  Document obsolete exceptions and their replacements.
  _

Enter newline · Ctrl-D review · Ctrl-X Ctrl-E external editor · Esc back

Tip: write in English when possible.

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Last focused: Sun, Aug 2, 22:14
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

On entry, the complete existing original text is selected with the accessible
treatment of UX-A02; the code block cannot show that styling. An absent
description starts empty. Input, cursor, newline, paste, search suspension,
and review follow UX-159. Slash is literal content here, so this active editor
does not display `[/] more...`. Escape behavior follows UX-160. None of these
editor operations mutates domain state. `Ctrl-X Ctrl-E` follows UX-162 and
returns either to this editor or to the same UX-S42/UX-S45 preview that
`Ctrl-D` would have opened.

## UX-S44 — Leave changed description draft

```text
Leave description editor?

*[k]eep the draft
 [d]iscard it
 [c]ontinue editing
 [?] I don't know

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Last focused: Sun, Aug 2, 22:14
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

Keep is the visible default and means an interaction checkpoint, not a Raw,
history event, or accepted description. It returns to UX-S39; selecting
description again resumes the exact buffer. Discard returns without the draft.
Continue restores UX-S43 at the exact cursor and selection. Uncertainty
explains that distinction and restores this screen. Crash recovery follows
UX-160 and UX-030.

## UX-S45 — Remove-description preview

```text
Remove description?

#rrsr "Review Rock Splitter rules"

The attached Raw material will be preserved.
Its history and other links will remain unchanged.

[y]es    [e]dit    [n]o    [?] I don't know

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Last focused: Sun, Aug 2, 22:14
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

Yes detaches only `RawLink(role = description)` under WRK-105 and reaches
UX-S38. Edit returns to the empty UX-S43 draft. No discards the draft and
restores UX-S39. Question mark explains preservation and restores the preview.
No option deletes or archives the Raw.

## UX-S46 — Existing-Brick Nature choice

```text
Update behavior:

#tm "Take medication"

Current Nature:

habit
    Missed windows affect history, but do not become overdue Work.

How should this behave now?

[a]tomic task           e.g. "Replace a broken light bulb"
[p]roject               e.g. "Migrate the website"
[c]ollection            e.g. "Books to read"
[f]inite checklist      e.g. "Pack for a trip"
[l]iving checklist      e.g. "Grocery list"
[r]epeatable            e.g. "Reread an article later"
recurring [o]bligation  e.g. "Take required daily medication"
[h]abit                 current
[s]cheduled commitment  e.g. "Attend an appointment"
[?] I don't know

────────────────────────────────────────
. <root>
  Personal › Health
. Last focused: Thu, Aug 6, 08:00
          Now: Thu, Aug 6, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

The current row is factual, not a default, and no row receives `*` in dumb
mode. Selecting it produces no mutation or direct human reclassification
claim. A different row begins target validation under MOD-059 and WRK-107;
it does not mutate immediately. Question mark reuses UX-K02..K03 over this
existing Brick. Escape restores UX-S37. Template provenance remains visible
through `/show`, not editable here.

## UX-S47 — Reclassification preview

```text
Change behavior?

#tm "Take medication"

From:
habit
    One standing Brick with expiring windows and a streak projection.

To:
recurring obligation
    Each required dose becomes an independently resolvable occurrence.

Preserved:

- Brick identity, title, importance, Domains, and history
- 14 previous habit-window outcomes

Will change:

- no new habit windows will be created
- the streak remains historical but stops extending
- future required doses will be released as occurrence Bricks

Schedule:

every day · 08:00
first occurrence: Fri, Aug 7 · 08:00

Apply this change?

[y]es    [e]dit    [n]o    [?] I don't know

────────────────────────────────────────
. <root>
  Personal › Health
. Last focused: Thu, Aug 6, 08:00
          Now: Thu, Aug 6, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

This is one concrete source-to-target example, not the complete matrix. Yes
applies one reversible WRK-107 action and reaches UX-S38. Edit restores the
typed schedule builder in this example; no discards the complete draft and
restores UX-S46. Question mark explains the shown preservation and
consequences, then restores the preview. Previous habit outcomes remain typed
history rather than being converted into obligation occurrences. A source
with unresolved incompatible active state must render its reconciliation
before this confirmable composition under `OPEN-NAT-001`.

## UX-S48 — Plan choice

```text
Plan:

#rrsr "Review Rock Splitter rules"

What do you want to change?

[s]tructure
    Its parent, parts, or list items.

[b]lockers
    What must happen before this Work can continue.

[r]esponsibility
    Who should do it.

[?] I don't know

[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Last focused: Sun, Aug 2, 22:14
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

This is a closed human dispatch screen, not a Plan object or relationship
editor. Dumb mode has no default. Structure, blockers, and responsibility
follow WRK-109. Assistance may mark one existing row and add one attributed
reason without changing the grammar. Escape restores UX-S37 without evidence.

## UX-S49 — Planned-blocker classification

Selecting `[b]lockers` on UX-S48 opens:

```text
#rrsr "Review Rock Splitter rules"

What needs to happen before you can continue?

🧱 another [t]ask must be completed
👤 someone must [r]espond
🗓️ wait [u]ntil a date or time
📍 be at a [l]ocation
🔔 an [e]vent or condition must occur
❓ [?] I don't know

[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Last focused: Sun, Aug 2, 22:14
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

The question, choices, shortcuts, typed builders, and previews are shared with
UX-S02. This plan origin deliberately omits `Continue without identifying it?`
and `[s]kip anyway`: there is no blocker-classification skip to defer. A
confirmed result records its typed prerequisite plus only the update origin's
WRK-102 consequence; this classifier adds no blocker skip evidence or
cooldown. Escape or reverse navigation restores UX-S48 without an event.

## UX-S50 — Structure intent

```text
Structure:

#rrsr "Review Rock Splitter rules"

What do you want to organize?

[w]ithin larger Work
    Move this Brick under other Work, or to root.

[p]arts
    Break it down, add parts, or organize existing child Bricks.

list [i]tems
    Add, change, resolve, or reopen entries shown together.

[?] I don't know

[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Last focused: Sun, Aug 2, 22:14
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

The three intents remain visible for every Nature and dumb mode has no
default. `within larger Work` changes only composition placement. `parts`
means independently tracked child Bricks; `list items` means entries shown and
executed with one checklist owner. An unsupported choice opens an explicit
Nature proposal and reconciliation under WRK-112 rather than disappearing,
failing generically, or converting state silently. Assistance may mark one
existing row or precede it with a complete UX-060 proposal; rejecting either
restores this exact screen. Escape restores UX-S48 without evidence.

## UX-S51 — Move preview with Domain contrast

```text
Move this Brick?

#rrsr "Review Rock Splitter rules"

From:
#rs "Rock Splitter"

To:
#hr "House renovation"

Context differs:

This Brick:
Orbit › R&D › Rock Splitter

New parent:
Personal › Housekeeping

These Domain paths do not overlap.
Moving will not change the Brick's Domains.

[y]es, keep current Domains
[c]hange Domains...
[n]o
[?] I don't know

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Last focused: Sun, Aug 2, 22:14
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

The dumb core derives only equality, Domain-tree ancestry, set overlap,
disjointness, or absence from explicit direct memberships. Any unequal sets
render their complete paths; `do not overlap` is a structural fact, not a
semantic judgment. Yes changes only composition and preserves every current
membership. Change Domains opens canonical context editing and returns to one
combined preview. No restores the still-uncommitted parent selector. Question
mark follows a bounded explanation or existing action without inventing the
human's desired context. Assistance may recommend change with an attributed
semantic reason, but cannot alter this comparison or mutate silently.

## UX-S52 — Parent selector

```text
Move within larger Work:

#rrsr "Review Rock Splitter rules"

Current parent:
#rs "Rock Splitter"

New parent ›

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Last focused: Sun, Aug 2, 22:14
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

Typing `#` or part of a title opens the same input-owned autocomplete:

```text
  <root>
  #rsm "Rock Splitter migration"
  #rdf "R&D features"
  #pi "Product improvements"
  New larger Work...
```

No result is a dumb default. Every Brick result uses its complete human
reference. The current parent is rendered with `current` when it matches the
query; selecting it is an event-free no-op. The moving Brick and descendants
are absent rather than selectable cycle errors. `<root>` removes the parent.
`New larger Work...` opens an uncommitted canonical Work draft and returns to
one combined preview, so cancellation cannot leave a new orphan Brick. A
structurally incompatible existing parent remains selectable and enters the
explicit Nature reconciliation already required by WRK-112. Candidate
eligibility is identical across modes. Assistance may reorder or mark one
candidate with an attributed reason but cannot manufacture a candidate or
select it. Escape, Left Arrow, or empty-buffer Backspace restores UX-S50.

## UX-S53 — Compact move preview

When the selected existing parent has the same direct Domains, the dumb route
uses no contrast block:

```text
Move this Brick?

#rrsr "Review Rock Splitter rules"

From:
#rs "Rock Splitter"

To:
#rsm "Rock Splitter migration"

Domains stay the same.
An importance comparison comes next.

[y]es    [n]o    [?] I don't know

[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Last focused: Sun, Aug 2, 22:14
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

The Domain line is omitted when the moving Brick has no direct Domain. The
importance line appears only when reusable evidence leaves a genuinely
unresolved first comparator; otherwise acceptance goes directly to the
receipt. A move to literal root uses `To: <root>` and the same compact grammar,
because root is not a parent Brick with a Domain set. The screen has no
default, personality, similarity claim, Nature row, or `change Domains`
action. No and reverse navigation restore UX-S52 with its query intact.

Yes revalidates both records, commits composition placement plus a valid
provisional sibling position, and continues the existing importance insertion
without a draw or per-answer receipt. Exiting that sequence leaves the Brick
placed and future review visible in the ordinary footer. At resolution or
exit, UX-S38 shows only the changed fact:

```text
Within:
#rs "Rock Splitter"
→
#rsm "Rock Splitter migration"
```

Its ordinary actions remain `[u]pdate something else`, `[r]eturn to Work`, and
the slash palette. The first reaches the update hub, where `[c]ontext` remains
available; the compact preview does not hide or duplicate Domain editing.

## UX-S54 — Compact move uncertainty

```text
Would you expect to find #rrsr "Review Rock Splitter rules"
within #rsm "Rock Splitter migration" when organizing that Work?

[y]es    [n]o    [?] I don't know

[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Last focused: Sun, Aug 2, 22:14
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

Yes restores UX-S53 unchanged; the human must still press its `[y]es` to move.
No restores UX-S52 directly. Question mark shows the bounded explanation:

```text
Moving it may change:

- where it appears within larger Work;
- its importance position among the new siblings;
- whether the old or new larger Work needs a later scope review.

It keeps its identity, handle, meaning, Domains, blockers, waits,
delegations, focus state, and internal parts.

After seeing this, would you expect to find it there?

[y]es    [n]o    [?] I don't know

[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Last focused: Sun, Aug 2, 22:14
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

The second uncertainty response returns to UX-S52 without evidence or
mutation. The root variant asks whether the Brick belongs `at the top level`.
Contextual `/show` may inspect either complete record and then restore the
exact pending question. Escape, Left Arrow, and empty-buffer Backspace restore
UX-S53 unchanged from either question.

## UX-S55 — Existing parts

Selecting `parts` for a Brick that already has direct children opens one
bounded factual view:

```text
Parts:

#rlav2 "Recover Little Ant v1"

Active:

1. #wms "Write the migration specification"
2. #rui "Review the REPL interaction"
3. #cmt "Complete the Nature matrix"

Other:

#rva "Review the v0 archive" — done
… 2 more inactive parts

[a]dd parts    [o]rder active parts
[?] I don't know
[/] more...

────────────────────────────────────────
. <root>
  Personal › Projects
. Last changed: Mon, Aug 3, 08:40
           Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

Active rows use current importance order. At most ten active and five inactive
rows are rendered; exact overflow counts replace the rest. Inactive rows are
plain lifecycle facts and claim no current importance position. When no active
child exists, the active block renders `None.` rather than disappearing or
showing an empty list, and `order` is absent. Contextual
`/show #rlav2 "Recover Little Ant v1"` exposes the complete direct-child
projection and returns here without mutation. `order` is omitted when fewer
than two active children exist. It enters the ordinary continuous
`/order #rlav2` cadence; its UX-O03 result adds `[p]arts`, which returns here
without a draw, while its existing `resume` and `next` meanings remain.

The multi-subject screen never guesses which visible Brick a contextual
operation targets. Palette actions for showing, updating, moving, archiving,
or superseding a child require `#` autocomplete and render the resolved child
before proceeding. Add opens the additive UX-B00 variant. Escape, Left Arrow,
or empty-buffer Backspace restores UX-S50 unchanged.

## UX-S56 — Parts uncertainty

```text
Parts are separate Bricks. Each one can appear as Work on its own.

Should each intended item be able to appear separately as Work?

[y]es    [n]o    [?] I don't know

[/] more...

────────────────────────────────────────
. <root>
  Personal › Projects
. Last changed: Mon, Aug 3, 08:40
           Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

Yes restores UX-S55. No restores UX-S50, where `list items` remains visible.
Question mark shows the bounded distinction and repeats the question once:

```text
Each part has its own importance, blockers, dates, and history.
An active finite parent is not normally suggested while unfinished parts
remain. Finishing every part releases a scope review; it does not complete
the parent automatically.

List items are different: they are shown together through one owner.

Should each intended item be able to appear separately as Work?

[y]es    [n]o    [?] I don't know

[/] more...

────────────────────────────────────────
. <root>
  Personal › Projects
. Last changed: Mon, Aug 3, 08:40
           Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

A second uncertainty response returns unresolved to UX-S50. Escape, Left
Arrow, and empty-buffer Backspace restore UX-S55 from either question. No
answer is evidence about Nature, importance, completion, or scope.

## UX-S57 — Parts behavior distinction

When the affected Brick cannot own independently focusable parts, dumb mode
asks only the distinction implied by the already-selected intent:

```text
Parts need a behavior change:

#rrsr "Review Rock Splitter rules"

Current behavior: atomic task

What should happen after its planned parts are finished?

[f]inish one outcome
    Review the whole Work and complete it as one finite scope.
    e.g. "Migrate the website"

[k]eep accepting parts
    Members may come and go without completing the larger Work.
    e.g. "Books to read"

[?] I don't know
[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Last focused: Sun, Aug 2, 22:14
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

The two rows resolve `project` and `collection`, respectively, but no Nature
change, draft, or authority claim is recorded here. A selected row first
enters every target-required builder and supported reconciliation, then UX-B00.
If a required reconciliation has no defined v1 choice, the route ends in its
typed educational boundary and offers return; it never exposes a premature
`yes`.

Question mark uses the established finite-versus-continuing alternate probe:

```text
Should this Brick remain active after one complete set of parts is finished?

[y]es    [n]o    [?] I don't know

[/] more...
```

Yes resolves `keep accepting parts`; no resolves `finish one outcome`. The
later combined preview remains the only confirmation. A second uncertainty
response returns unresolved to UX-S50 for the subject Brick, or UX-S52 when
the affected Brick was a proposed parent. Escape, Left Arrow, and
empty-buffer Backspace restore the exact origin from the first screen and
restore UX-S57 from the alternate probe. Powered-up or Skill may mark one row
with one attributed reason but cannot select it.

## UX-S58 — Parent behavior and move preview

When an otherwise eligible parent needs a behavior change, the final preview
names the parent first and the moving Brick second:

```text
Apply these changes?

Larger Work will change:

#rsm "Rock Splitter migration"

Behavior:
atomic task
→
project

Preserved:
identity, handle, meaning, Domains, history, and Template provenance

Will change:
- it can own independently focusable parts;
- while active parts remain, they are suggested instead of the larger Work;
- finishing all finite parts releases a scope review, not automatic completion.

This Brick will move:

#rrsr "Review Rock Splitter rules"

From:
#rs "Rock Splitter"

To:
#rsm "Rock Splitter migration"

Domains stay the same.

[y]es    [n]o    [?] I don't know

[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Last focused: Sun, Aug 2, 22:14
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

The behavior block contains every applicable UX-S47 preserved, stopped,
started, configured, reconciled, focus, WIP, eligibility, restoration, and
origin consequence; the example is the no-conflict minimum. If direct Domain
sets differ, the existing UX-S51 mechanical block replaces `Domains stay the
same.` and adds `[c]hange Domains...` before no. Change-Domains suspends the
combined preview in the canonical editor and returns here. No restores UX-S52
with its query; reverse navigation restores the nearest Nature builder or
reconciliation. Yes appears only after all required decisions exist and
commits both subjects atomically under WRK-116.

## UX-S59 — Parent behavior and move uncertainty

```text
Should #rsm "Rock Splitter migration" become larger Work that owns
#rrsr "Review Rock Splitter rules" as a separate part?

[y]es    [n]o    [?] I don't know

[/] more...

────────────────────────────────────────
. #rs "Rock Splitter"
  Orbit › R&D › Rock Splitter
. Last focused: Sun, Aug 2, 22:14
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #rrsr
```

Yes restores UX-S58 unchanged; no restores UX-S52 with its query. Question
mark explains once that the parent changes behavior, the child moves, direct
Domains remain as shown, importance is local to the new siblings, and any
listed focus, WIP, scope-review, or restoration consequence also applies. It
then repeats the same question and actions. A second uncertainty response
returns unresolved to UX-S52. Escape, Left Arrow, or empty-buffer Backspace
restores UX-S58 from either question. `/show` may inspect either cited Brick
and return to the exact question without mutation.

## UX-K01 — Nature choice

```text
"Fix a bug on website"

How should this behave?

[a]tomic task           e.g. "Replace a broken light bulb"
[p]roject               e.g. "Migrate the website to a new host"
[c]ollection            e.g. "Books to read"
[f]inite checklist      e.g. "Pack for the August trip"
[l]iving checklist      e.g. "Grocery list"
[r]epeatable            e.g. "Reread this article in six months"
recurring [o]bligation  e.g. "Pay the monthly rent"
[h]abit                 e.g. "Walk three times a week"
[s]cheduled commitment  e.g. "Take flight AD123 to Montevideo"
[?] I don't know

────────────────────────────────────────
. <root>
  <no Domain>
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 0 bricks, 0 raws, 0 reviews
  mode: dumb, focus: idle
```

`?` opens UX-K02. This screen occurs only after Raw triage has chosen Work or
an explicit contextual builder has already chosen that result; ordinary Feed
never opens it. No selection is a hidden fallback and no Template appears on
this screen. Each example is illustrative UI copy, not input to
classification or Template selection.

## UX-K02 — Guided Nature discovery

```text
"Fix a bug on website"

Will completing this once finish the whole intention?

[y]es    [n]o    [?] I don't know

────────────────────────────────────────
. <root>
  <no Domain>
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 0 bricks, 0 raws, 0 reviews
  mode: dumb, focus: idle
```

Successive `yes`, `no`, and uncertainty answers traverse the bounded,
inspectable tree in `FED-024..027`. Escape returns to the immediately preceding
question without recording an answer. Repeated uncertainty at one split leaves
Raw-to-Work materialization pending rather than creating a Brick.

## UX-K03 — Discovered Nature confirmation

```text
"Fix a bug on website"

Classification: atomic task
Because: one completion finishes the whole intention
and no separately tracked parts are required.

Is this right?

*[y]es    [n]o    [?] I don't know

────────────────────────────────────────
. <root>
  <no Domain>
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 0 bricks, 0 raws, 0 reviews
  mode: dumb, focus: idle
```

`yes` accepts the Nature and continues Work materialization. `no` returns to
UX-K01 with the source Raw preserved. `?` restarts UX-K02 at Q0. Escape
returns to the last decisive question. These are navigation and local
classification changes, not domain events or semantic undo.

## UX-K04 — Assisted Template proposal

```text
Suggested setup

Template: bug_fix
Nature: atomic task
Source: software-development pack

Use this setup?

[y]es    [n]o    [?] I don't know

────────────────────────────────────────
. <root>
  <no Domain>
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 0 bricks, 0 raws, 0 reviews
  mode: powered up, by: /bin/claude-fast.sh, focus: idle
```

The skill uses the same confirmation envelope. `no` restores the unchanged
source Raw and enters UX-K01; no Nature, Template, or ranking evidence is
accepted from the rejected proposal. This is a declared `UX-060` gateway:
it may replace UX-K01 through UX-K03 only when its accepted result contains
the same canonical Nature and optional Template values that those dumb screens
could resolve.

## UX-K05 — Dumb Template choice

```text
Nature: living checklist

Choose an optional setup:

[g]rocery list    e.g. "A reusable list shown all at once"
[n]o template     keep only the living-checklist behavior
[?] I don't know

────────────────────────────────────────
. <root>
  <no Domain>
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 0 bricks, 0 raws, 0 reviews
  mode: dumb, focus: idle
```

The catalog contains only Templates compatible with the resolved Nature.
Every option is explicit and none receives `*` in dumb mode. Skill or
powered-up mode may highlight one attributed compatible suggestion. If the
installed catalog has no compatible Template, materialization skips this
screen and continues with the resolved Nature.

## UX-K06 — Dense scheduled-commitment Template choice

Eleven compatible built-in Templates fit one explicit dumb choice without
repeating a shortcut character:

```text
Nature: scheduled commitment

Choose an optional setup:

[f]light                 e.g. "Flight AD123 to Montevideo"
scheduled [t]ransport    e.g. "Train from London to Paris"
[a]ppointment            e.g. "Dentist appointment"
[m]eeting                e.g. "Quarterly planning meeting"
[e]vent attendance       e.g. "Attend the security conference"
[r]eservation            e.g. "Dinner reservation"
[c]lass session          e.g. "Spanish lesson"
e[x]am                   e.g. "Driver's license exam"
[w]ork shift             e.g. "Saturday support shift"
[s]ervice window         e.g. "Internet technician visit"
[h]otel stay             e.g. "Stay at Hotel Carrasco"
[n]o template            keep only the scheduled-commitment behavior
[?] I don't know

────────────────────────────────────────
. <root>
  <no Domain>
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 0 bricks, 0 raws, 0 reviews
  mode: dumb, focus: idle
```

No category screen is introduced while this flat choice remains usable.
Future categories or pagination must follow `UX-056` and preserve the same
Template identities.

## UX-B00 — Dumb part collection

When the batch must reclassify the Brick, dumb mode collects pending titles
under the decomposition heading:

```text
Break into parts:

#ctpe "Carry this enormous rock"

Parts:

1. "Ask someone to help"
2. "Get a wheelbarrow"
3. › _

Tip: write Brick titles in English.

[Enter] add · empty [Enter] review
[/] more...

────────────────────────────────────────
. <root>
  Personal › Housekeeping
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:06
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

The first rendering has no numbered titles and an active `1. ›` input.
Non-empty Enter appends the draft and advances the number. Empty Enter exposes
`review` only after two parts exist when the batch reclassifies the Brick.
Whenever the current Nature already supports parts, the heading is `Add
parts:`, the list label is `New parts:`, and empty Enter exposes `review` after
one draft—even when this is its first child. That compatible route comes
directly from UX-S50 when no child exists and from UX-S55 otherwise. The title
hint is visually dim. Reverse navigation from an already empty additive input
restores its exact UX-S50 or UX-S55 origin; the reclassification variant
restores UX-S57. Neither path crosses semantic undo or creates durable state.

## UX-B00A — Assisted decomposition draft

With sufficient evidence, powered-up mode or the Skill may precede UX-B00:

```text
Break into parts:

#ctpe "Carry this enormous rock"

Suggested parts:

1. "Find someone to help"
2. "Get suitable moving equipment"
3. "Move the rock"
4. "Return the equipment"

Suggested from the Brick's title and description.

Use this draft?

[y]es    [e]dit    [n]o    [?] I don't know
[/] more...

────────────────────────────────────────
. <root>
  Personal › Housekeeping
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:06
. 18 bricks, 7 raws, 3 reviews
  mode: powered up, by: /bin/claude-fast.sh, focus: idle
```

`Use this draft?` distinguishes accepting assisted input from the later
`Apply this change?` mutation boundary. `yes` enters UX-B01 rather than
committing. `edit` opens UX-B00 with these
four drafts; `no` opens it empty; and uncertainty reveals the specific source
evidence before restoring this screen. No action is the default. The Skill
uses the same envelope and action semantics. Insufficient evidence goes
directly to UX-B00 without a weak or decorative proposal. On an additive
route, the heading and list label become `Add parts:` and `Suggested new
parts:` without changing any action.

## UX-B00B — Assisted inline suggestion

An assisted UX-B00 may add one visually subordinate completion below its
empty active line:

```text
3. › _

Suggestion: "Move the rock to its destination"

[Tab] accept suggestion
```

Tab copies the suggestion into the editor but does not submit it. Typing any
ordinary character dismisses the suggestion and writes the user's own title.
The Skill and graphical surfaces expose the same semantic action without
requiring a literal Tab key.

## UX-B01 — Preview a part batch

```text
Break into parts:

#ctpe "Carry this enormous rock"

This Brick will become a project.
Little Ant will suggest its parts instead of the whole.

Parts:

1. "Ask someone to help"
2. "Get a wheelbarrow"
3. "Move the rock"

These parts start as atomic tasks and in the order above.
Little Ant may review their Nature and importance later.

Apply this change?

[y]es    [e]dit    [n]o    [?] I don't know
[/] more...

────────────────────────────────────────
. <root>
  Personal › Housekeeping
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:08
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

The numbered rows are pending parts, not Bricks, so no child handle is shown
or reserved before `yes`. Confirmation preserves the parent identity, changes
its Nature only when the preview says so, creates every child and its handle
atomically, and installs the displayed low-confidence sibling order without
interposing importance questions. A resulting Nature governed by MOD-015
stops appearing as ordinary Work while incomplete execution-bearing children
exist; a scheduled commitment keeps its anchored focus and hard interval
precedence while preparation children remain independently focusable.
Completing a finite execution-bearing final child releases parent-scope review
without silently completing or immediately refocusing the parent.

`edit` restores UX-B00 with all drafts. `no` discards them and restores UX-S55
for an existing-parts origin, UX-S50 for a no-existing-child Plan origin,
UX-S06 for `big`, or the exact direct-command origin. It records no symptom,
break, or other evidence. Escape, Backspace, and Left Arrow restore UX-B00 with the drafts
under UX-019. `?` explains the project transition, reviewable default Natures,
provisional importance run, and any assisted provenance. The palette provides
detail and dry-run inspection without competing with confirmation.

An assisted preview preserves the same composition and adds only applicable
exceptions, for example:

```text
2. "Arrange professional transport"
   Nature: project · AI-suggested · review later
3. "Move the rock"
   Depends on part 2 · AI-suggested · review later

Starting order: AI-suggested · review later
```

Every assisted claim remains attributed after acceptance. If no exception
exists, the preview remains identical to dumb UX-B01.

When the batch also changes Nature, the simple `This Brick will become...`
sentence expands into the same complete human-facing blocks as UX-S47:
`Behavior: From → To`, `Preserved`, every applicable `Will stop` and `Will
start`, target configuration, explicit reconciliations, and focus, WIP,
eligibility, restoration, or origin consequences. The parts and their
provisional order follow those blocks. No `yes` is rendered until the
capability-delta owner supplies every required reconciliation. This combined
preview, rather than UX-S57, is the human confirmation of both Nature and
structure.

Adding to an already child-owning Brick uses the same confirmation grammar but
states only the real additive consequence:

```text
Add parts:

#rlav2 "Recover Little Ant v1"

New parts:

1. "Write replay fixtures"

Existing parts stay unchanged.
The new parts start after the current active parts, in the order above.
Little Ant may review their Nature and importance later.

Apply this change?

[y]es    [e]dit    [n]o    [?] I don't know
[/] more...
```

This variant names no Nature change. If the parent is current focus, it adds
`Current focus stays on this Brick.` If a `scope_closure_review` is pending,
it adds `The pending scope review will no longer be needed after active work
is added.` Exact or
bounded duplicate candidates enter FED-016 before this final preview; no title
match silently reuses or merges a child. A stale change to the parent Nature,
child set, focus, or pending scope review re-renders the applicable preview
before acceptance.

## UX-B02 — Committed break result

Accepting UX-B01 mutates once and returns a stable result without drawing:

```text
Broken into 3 parts:

#ctpe "Carry this enormous rock"
├─ #asth "Ask someone to help"
├─ #gaw "Get a wheelbarrow"
└─ #mtr "Move the rock"

The parts can now appear as Work.
The parent will return for review after all three are done.

[n]ext    [/] more...

────────────────────────────────────────
. <root>
  Personal › Housekeeping
. Changed: Mon, Aug 3, 09:08
      Now: Mon, Aug 3, 09:08
. 21 bricks, 7 raws, 7 reviews
  mode: dumb, focus: idle
```

The three child handles become durable only in the accepted transaction. The
`bricks` count rises from 18 to 21 because the active parent remains in the
dataset and three active children were added. The `reviews` count rises from
3 to 7: three child `nature_review` opportunities and one sibling
`importance_run_review`. All four enter the weighted lottery immediately with
low positive weight. They may therefore be drawn next, although ordinary Work
or another review may win the replay-stable draw instead. A later review skip
can cool one opportunity without lowering this unresolved count.

`next` invokes the ordinary forecast only after the keypress. It does not
prefer the first displayed child merely because it appears first. The palette
offers contextual `/undo` and inspection; exact compensation still obeys
event-history, identity, and precondition rules rather than deleting the
accepted transaction.

For an additive direct `/break` or served-work route, the same result derives
its heading and consequences instead of pretending that the parent was first
decomposed:

```text
Added 1 part to:

#rlav2 "Recover Little Ant v1"
└─ #wrf "Write replay fixtures"

The new part can now appear as Work.

[n]ext    [/] more...
```

A finite parent mentions future scope review; an open-ended collection does
not. Conditional lines report unchanged current focus and invalidation of a
formerly pending scope review. A Plan-origin acceptance instead uses UX-S38:
its fact block shows `Active parts: <before> → <after>`, lists every added
`#handle "title"`, and shows either conditional consequence. That additive
before/after block satisfies the ordinary update-receipt contract without
inventing a prior value for each new child.

## UX-N01 — Nature review

When a lazy `nature_review` wins the ordinary lottery:

```text
Review:

#asth "Ask someone to help"

Current Nature:

atomic task

Assigned automatically when
#ctpe "Carry this enormous rock" was broken into parts.

Is this the right Nature?

[y]es    [c]hange    [s]kip    [?] I don't know
[/] more...

────────────────────────────────────────
. #ctpe "Carry this enormous rock"
  Personal › Housekeeping
. Assigned: Mon, Aug 3, 09:08
         Now: Mon, Aug 3, 09:09
. 21 bricks, 7 raws, 7 reviews
  mode: dumb, focus: idle
```

No action receives `*`: the screen exists to obtain independent human
judgment. `yes` keeps `atomic_task`, records direct human authority while
retaining `break_default` history, resolves only this marker, and makes the
next rendered footer show six unresolved reviews. `change` opens the canonical
Nature choice adapted to this existing Brick and previews any consequential
reclassification before mutation. `skip` leaves the count at seven, applies
review-specific cooldown, and never opens UX-S01. Contextual uncertainty and
reverse navigation preserve the selected opportunity.

When assistance originated the current claim, the source sentence changes
without changing the grammar, for example:

```text
Suggested by powered-up assistance from the title and parent context.
```

The primary screen never exposes a model key, prompt, or source enum.

## UX-O01 — Lazy importance-run review

When an `importance_run_review` wins the ordinary lottery, the comparison
begins directly with its proposition:

```text
Is

#asth "Ask someone to help"

    more important than

#gaw "Get a wheelbarrow"
?

[m]ore important    [l]ess important
[s]kip              [?] I don't know
[/] more...

────────────────────────────────────────
. #ctpe "Carry this enormous rock"
  Personal › Housekeeping
. Ordered: Mon, Aug 3, 09:08
       Now: Mon, Aug 3, 09:11
. 21 bricks, 7 raws, 7 reviews
  mode: dumb, focus: idle
```

No `Review:` heading or `*` precedes the ordinary comparison grammar. An
accepted direction records one direct human relation and ends this selected
lottery interaction. If the provisional run remains unresolved, its one
`importance_run_review` marker and footer count remain; if the answer settles
the run, that marker resolves and the count falls by one. The stable result
does not draw automatically. A later explicit `[n]ext` uses FOC-041, so another
importance-maintenance opportunity is more likely but never guaranteed.

The first `skip` may replace the comparator with one bounded nearby alternative
under IMP-008. A second skip ends the interaction, retains provisional order,
and applies review cooldown. `?` enters UX-O11; its read-only inspection may
expose the complete sibling run, entered or assisted source, applicable
evidence, and why this pair is unresolved without answering. Reverse
navigation preserves the pending review.

When entered through explicit `/order`, UX-O01 is visually identical. The
cadence changes only after an accepted direction: the core immediately renders
the next pair selected by the same resumable `org-sort-tasks` state. No stable
per-pair result or global draw intervenes until the scope becomes coherent or
the user exits.

## UX-O02 — Explicit ordering scope

Entering `/order` without an argument chooses the bounded work set before any
comparison:

```text
Order what?

*[a]ll groups
    12 groups · 21 unresolved

[c]urrent group
    #ctpe "Carry this enormous rock"
    3 siblings · 1 unresolved

[d]omain
    Personal › Housekeeping
    4 groups · 7 unresolved

[p]ick a Brick or Domain...
[?] I don't know
[/] more...
```

The current-group row is present only when the suspended context identifies a
parent with unresolved child ordering. The Domain row is present only when a
current Domain contains unresolved sibling groups. Counts describe the runs
that would be maintained, not cross-parent comparison candidates. `All groups`
remains first and carries the factory dumb default. Pressing `a`, literal `*`,
or Enter therefore starts the same dataset-wide sequence under UX-015.

Choosing `pick`, or typing an argument after `/order`, opens one revisioned
autocomplete. It searches Brick titles as well as handles, so a title fragment
does not require the user to know `#bs`:

```text
Order:

› /order "Bring someth

Sibling groups
  /order #bs "Bring something..."

↑/↓ select · Enter start · Esc back
```

Unprefixed text may return visibly separated `Sibling groups` and `Domains`
sections when both kinds match. Typing `#` narrows directly to parent Bricks.
Every Brick option shows the complete typed rendering from MOD-010, while
selecting it carries the UUID-backed reference rather than relying on its
mutable title. Selecting a Domain inserts its complete quoted path, so the
visible command becomes, for example, `/order "Personal › Housekeeping"`.
The selector never requires title, handle, or path memorization, never silently
chooses between ambiguous matches, and does not offer creation. After
selection, UX-O01 starts immediately and remains in direct cadence until the
selected scope is coherent or the user exits.

## UX-O03 — Continuous ordering result

Escape or empty-input Backspace on an unanswered pair leaves an incomplete
explicit session with a stable, no-draw result:

```text
Ordering paused:

Personal › Housekeeping

4 comparisons recorded.
2 sibling groups still need review.

[r]esume    [n]ext    [/] more...
```

`resume` restores the same resumable scope and asks its next unresolved pair.
`next` leaves direct maintenance and performs a fresh global forecast draw.
The word `paused` describes only this resumable command result; it does not add
a Brick state. Left Arrow on a comparison does not open this result: it offers
semantic undo of the latest accepted comparison under UX-U01.

When the selected scope becomes coherent, the direct sequence terminates
without requiring Escape:

```text
Order reviewed:

Personal › Housekeeping

6 comparisons recorded.
4 sibling groups are coherent.

[n]ext    [/] more...
```

Both variants retain the ordinary persistent footer below the shown content.
Neither performs an automatic forecast draw.

When continuous ordering was entered from UX-S55, both result variants add a
contextual return without changing the existing exits:

```text
[r]esume    [p]arts    [n]ext    [/] more...
```

The completed variant omits `resume`. `parts` restores UX-S55 against the
current revision without a draw; `next` still leaves maintenance for the
global forecast. No ordering answer returns to Parts before this stable result.

If the pass finishes with provisional placements, the same completed variant
replaces the coherence sentence with the unresolved confidence count:

```text
Order reviewed:

Personal › Housekeeping

6 comparisons recorded.
2 placements still need review.

[n]ext    [/] more...
```

Those placements are already deterministic and usable; `need review` means
future low-confidence maintenance, not that `/order` is blocked or incomplete.

## UX-O04 — Lottery importance receipt

The one accepted relation in a lottery-selected `importance_run_review` ends
that deliberately one-comparison cycle with only a compact receipt:

```text
✓ Importance recorded.

[n]ext    [/] more...
```

If that relation also resolves the sibling run, the receipt becomes:

```text
✓ Order reviewed.

[n]ext    [/] more...
```

The ordinary footer remains below either variant. The result repeats neither
Brick, proposition, nor explanation; those remain available through
contextual `?`, `/history`, and structured inspection. It contains no
personality phrase and performs no draw. `[n]ext` invokes the global forecast,
where FOC-041 may favor another importance-maintenance opportunity without
guaranteeing one. Left Arrow or contextual `/undo` can preview compensation of
the recorded comparison.

## UX-O05 — Lottery provisional-placement result

The second skip in a lottery-selected importance cycle places the subject
provisionally and returns one honest no-draw result:

```text
Positioned for now:

#asth "Ask someone to help"

Little Ant will revisit its importance later.

[n]ext    [/] more...
```

The persistent footer retains the parent and Domain context. The result creates
no equality or comparison edge, does not claim that the Brick is unimportant,
and does not expose a numeric confidence score. `[n]ext` returns to the global
forecast after the review-specific cooldown has been recorded. Contextual
inspection exposes the skipped comparators, provisional position, and future
review pressure.

## UX-O06 — Fresh importance contradiction

When a pending answer closes a recent strong cycle, the core stops before
changing the effective order:

```text
Contradiction detected:

Jul 10, 2026 · 00:23
#a "A" was more important than #b "B"

Jul 10, 2026 · 00:29
#b "B" was more important than #c "C"

Just now
#c "C" was more important than #a "A"

What happened?

[c]hanged
    C is now more important than A.
    Stop using the two earlier judgments.

[m]istake
    I meant A is more important than C.

[?] I don't know
    Help me compare all three.

[/] more...
```

No action is the default, and this required resolution is not an ordinary
lottery opportunity, so it has no `skip`. `changed` removes the two older path
edges only from current calculation; all three statements and the explicit
resolution remain in history. `mistake` records direct `A > C` and retains the
two coherent earlier judgments. Escape leaves the resolution pending and the
last coherent effective order unchanged.

## UX-O07 — Three-way contradiction aid

Choosing uncertainty on UX-O06 opens one direct temporal tradeoff:

```text
Let's untangle this:

If only one of these could ever be done, which one should it be?

[a] #a "A"
[b] #b "B"
[c] #c "C"

[?] I still don't know
[/] more...
```

Choosing `A` records `A > B` and `A > C`; choosing `B` records `B > A` and
`B > C`; choosing `C` records `C > A` and `C > B`. In each case the direct
edges incompatible with that answer retire from current calculation, while a
still-coherent relation between the other two may remain. This resolves the
three-way cycle without pretending to have re-evaluated the losers against
each other.

A longer cycle reuses this exact composition over deterministic overlapping
triads. For `A > B > C > D > A`, the first aid compares `D`, `A`, and `B`.
If `D` wins and `D > B > C > D` remains, the next aid compares `D`, `B`, and
`C`. Every answer recomputes the smallest cycle; no unnecessary later triad is
shown. The counterfactual deliberately says `ever`, not `right now`, because it
measures importance rather than urgency.

## UX-O08 — Provocative transitive validation

The primary screen for a provocative validation is deliberately identical to
UX-O01. It does not announce that the current order implies an answer. If the
user opens contextual uncertainty, secondary evidence may explain:

```text
This comparison has not been asked directly.

The current order infers it through:

#a "A" > #b "B" > #c "C"

No answer has been recorded.
```

Returning restores the untouched proposition. The inferred direction never
creates `*`; only the user's direct `more` or `less` response can validate or
contradict it.

## UX-O09 — Still-uncertain contradiction result

Selecting `[?] I still don't know` on UX-O07 ends that bounded aid without
forcing a winner:

```text
Still uncertain:

Keeping the previous order for now.

3 placements need review.

[n]ext    [/] more...
```

The previous coherent order remains usable, all three conflicting judgments
remain in history, and the affected segment receives one FOC-043 opportunity
after its cooldown. The count is structural and human-facing; the screen does
not expose confidence floats. It contains no personality phrase and performs
no draw. In explicit `/order`, an unaffected segment follows immediately; this
result is deferred until the command reaches its next actual boundary.

## UX-O10 — Provocative-validation skip result

The second validation skip, or the first when no alternative validation pair
exists, ends the one-shot cycle without changing order or confidence:

```text
No change for now.

The current order stays in place.

[n]ext    [/] more...
```

The result has the ordinary footer, no personality phrase, and no automatic
draw. Its pair-specific cooldown is interaction history, not a persistent
review marker, so the unresolved-review footer count does not increase. The
independent validator may consider the same never-directly-asked pair again
after cooldown if its ordinary configured sampling branch selects it.

## UX-O11 — Guided importance discovery

Question mark on UX-O01 starts IMP-040 with the first displayed Brick:

```text
#a "Launch the landing page"
#b "Interview prospective customers"

Do you understand what result #a is meant to produce
and what would be lost if it were never done?

[y]es    [n]o    [?] I don't know
[/] more...

────────────────────────────────────────
. #p "Launch the product"
  Work › Product launch
. Ordered: Mon, Aug 3, 09:08
       Now: Mon, Aug 3, 09:11
. 21 bricks, 7 raws, 7 reviews
  mode: dumb, focus: idle
```

Successive screens ask exactly one Q0..Q8 question while retaining both Brick
citations. Node-local question-mark behavior follows IMP-041: it may converge
on the same recovery screen as `no` without becoming a negative answer.
Inspection opens `/show` and returns to the applicable checkpoint. Reverse
navigation restores the preceding question; from Q0 it restores UX-O01 with
the same pair and sorter state.

## UX-O12 — Discovered importance confirmation

When Q4 explicitly chooses the first Brick:

```text
Importance judgment:

#a "Launch the landing page"

    is more important than

#b "Interview prospective customers"

Because, if only one could ever be completed, you chose #a.

Record this judgment?

*[y]es    [n]o    [?] I don't know
[/] more...
```

The reverse direction uses the same composition with the citations swapped.
`yes`, `*`, or Enter records exactly one direct human edge and resumes the
owning ordering cadence. `no` returns to the decisive counterfactual;
uncertainty returns there with its alternate probe. Reverse navigation records
nothing.

## UX-O13 — Either-order confirmation

When Q6 explicitly accepts either relative order:

```text
Ordering judgment:

Either order is fine between

#a "Buy toilet paper"
#b "Buy milk"

Place them next to each other in either deterministic order?

*[y]es    [n]o    [?] I don't know
[/] more...
```

Acceptance records pair-local `either_order` evidence under IMP-042, not
equality or a strict direction. During insertion the subject is placed beside
the comparator using the versioned stable tie-break; an existing maintenance
run may preserve its stable local order. The screen does not promise permanent
adjacency. `no`, uncertainty, and reverse navigation return to Q6 without
mutation.

## UX-O14 — Importance investigation input

An accepted Q1, Q3, or Q7 investigation leaf opens contextual Feed:

```text
More evidence is needed to compare:

#a "Launch the landing page"
#b "Interview prospective customers"

What would help determine which Brick is more important?

›

Tip: write in English when possible.

[/] more...
```

The dumb core supplies no method or title. Enter commits source Raw and
proceeds through ordinary Nature, placement, and Work confirmation; the
preview identifies the A/B importance review that will wait for this
investigation without making either Brick blocked. Escape or empty-buffer
Backspace restores the decisive tree question with the draft rules of UX-019.
Assisted proposals follow UX-138.

## UX-O15 — Provisional-placement confirmation

When Q8 explicitly declines the bounded nearby comparison:

```text
No honest direction was found.

Keep a deterministic provisional position near the current comparator
and review it later?

*[y]es    [n]o    [?] I don't know
[/] more...
```

Acceptance follows IMP-044: it creates no comparison, equality,
`either_order`, or skip evidence. It records only the deterministic placement,
low confidence, `uncertain_after_help` reason, and bounded future review
pressure. `no`, uncertainty, and reverse navigation return to Q8 without
mutation.

## UX-A01 — External-effect confirmation

The question derives from the typed effect purpose, such as `Send this
delegation?`, `Send this follow-up?`, or `Send this take-back notice?`. When a
follow-up approval is selected by the ordinary lottery:

```text
Send this follow-up?

Suggested message:

“Hi Bento, could you share an update on
#rrsr "Review Rock Splitter rules"?”

[y]es    [e]dit    [n]o    [l]ater    [s]kip
[?] I don't know

To: @bc "Bento Camargo"
Reason: delegation follow-up · eligible for 2 days

────────────────────────────────────────
. <root>
  <no Domain>
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

`later` opens a date screen and records nothing until the absolute date is
confirmed. `yes` approves the exact displayed effect. `no` permanently rejects
that effect instance, but does not cancel the Delegation, claim that its need
was resolved, or silently create a replacement. When this confirmation was
selected by the ordinary lottery, `skip` preserves both the pending effect and
its existing review instant and records only typed approval deferral, cooldown,
and future pressure. A confirmation reached directly rather than by the
lottery omits `skip` unless its own domain grammar independently permits
deferral. Contextual assistance explains these consequences and may route to
an alternative; it never changes the effect by itself. `edit` opens UX-A02;
editing returns to this complete preview and never sends the message.

## UX-A02 — Edit a suggested external message

```text
Edit the message:

› Hi Bento, could you share an update on
  #rrsr "Review Rock Splitter rules"?_

[Enter] preview    [Esc] back

To: @bc "Bento Camargo"
Reason: delegation follow-up · eligible for 2 days

────────────────────────────────────────
. <root>
  <no Domain>
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

On entry, every prefilled display cell is selected with the accessible
surface treatment; the code block cannot represent that styling literally.
Printable input or paste replaces all selected text, Backspace or Delete
clears it, and an arrow key removes the selection and positions the cursor
without editing. Enter returns to UX-A01 with the full edited payload under
`Message:`; it does not send. Escape returns with the prior suggestion intact.
Factory or model identifiers are absent from the primary screen. The
attributed origin and edit revisions remain inspectable through contextual
assistance, history, and structured projections.

## UX-D01 — Delegation strategy review

When an ordinary-lottery internal review reaches the configured soft cap:

```text
Review:

#rfr "Review the financial report"
Delegated to @bc "Bento Camargo"

2 follow-ups delivered · no outcome recorded

What should change?

[c]ontinue     — allow one more follow-up
[t]ake it back — return execution to you
[r]eassign     — hand it off to someone else
[e]scalate     — create explicit escalation work
[s]kip         [?] I don't know

────────────────────────────────────────
. <root>
  Orbit › Finance
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

`continue` increases the allowance by exactly one and enters the ordinary
follow-up route; it neither resets the count nor approves a message. `take it
back` and `reassign` enter Delegation reconciliation before responsibility or
eligibility changes. `escalate` enters a guided Feed preview for a separate
Brick and creates nothing silently. `skip` preserves the cap and all Delegation
state while applying only the typed review deferral, cooldown, and pressure.

## UX-D02 — Responsibility and initial handoff

Plan responsibility begins without assuming that a change is needed:

```text
Responsibility:

#rfr "Review the financial report"

Who should do this work?

[m]e
[s]omeone else...
[?] I don't know

[/] more...
```

With no nonterminal Delegation, `me` explains that the Work is already the
human's and returns to Plan without an event. With a proposed one it opens
cancellation; with an active one it opens take-back reconciliation.
`someone else` opens ordinary `@` autocomplete for new coverage, edits a
proposed target, or enters active reassignment; it never creates overlapping
responsibility. A project then asks the only currently resolved variable
factory scope:

```text
Delegate what to @bc "Bento Camargo"?

[b]rick only
    Bento owns this outcome. Its parts remain yours.

[w]hole scope
    Bento owns this outcome and its current and future parts.

[?] I don't know
```

Fixed Nature coverage skips this screen and appears as a fact later. A habit
ends educationally with a route to create separate enabling Work. Until the
scheduled-commitment boundary is closed, that Nature ends explicitly rather
than borrowing another scope.

```text
How should Little Ant follow up?

[o]nce
    Suggest at most one follow-up message.

[e]very review
    Keep suggesting when unresolved, always asking before sending.

[n]o automatic follow-up
    Keep reviewing status without suggesting messages.

[?] I don't know
```

No policy is preselected. Internal reviews continue under every row.

```text
How long after a handoff should we check again?

 [o]ne day
*[t]hree days
 one [w]eek
 [c]ustom...
 [?] I don't know
```

`*` or Enter accepts three days. Custom accepts a positive integer plus
`hours`, `days`, or `weeks`; calendar months are not guessed. The delay begins
at observed handoff, never while this builder is still open.

```text
How will the handoff happen?

[s]end using Work email
[m]anually
[?] I don't know
```

Only usable delivery bindings appear. With none, manual is the sole row and
visible default. The combined preview is:

```text
Delegate this work?

Work: #rfr "Review the financial report"
To: @bc "Bento Camargo"
Scope: brick only
Follow-up: once
Review after: 3 days from each handoff or status update
Handoff: manually

Suggested message:

“Hi Bento Camargo, could you take care of
#rfr "Review the financial report"?”

[y]es    [e]dit    [n]o    [?] I don't know

[/] more...
```

Yes creates only a proposed Delegation. An adapter route next reuses UX-A01
without lottery skip. A manual route shows the same editable message and:

```text
After you have delivered this message or otherwise made
the responsibility clear:

[h]anded it off    [e]dit message
[c]ancel delegation

[/] more...
```

`handed it off` activates and claims no reading, acceptance, or completion.
Cancel terminates the proposed Delegation without an external message.

The complete factory pattern catalog is:

```text
initial brick
Hi {recipient}, could you take care of {brick}?

initial whole scope
Hi {recipient}, could you take responsibility for {brick},
including its current and future work?

follow-up
Hi {recipient}, could you share an update on {brick}?

take-back
Hi {recipient}, I am taking responsibility for {brick} back.
No further action is needed from you.
```

`{recipient}` is the declared name and `{brick}` is the complete rendered
reference. Line wrapping is presentation only. Every pattern remains editable
and requires its own approval and observed delivery.

## UX-D03 — Internal Delegation review

```text
Review:

#rfr "Review the financial report"
Delegated to @bc "Bento Camargo"

Last handoff: Fri, Jul 31, 09:00

What happened?

[p]rogress update
reported [c]omplete
[r]efused
[n]o response
[t]ake it back
[s]kip    [?] I don't know

[/] more...
```

Progress and no-response results show the next review instant. Progress may
route separately to Feed if the human wants to retain the actual message as
Raw; the outcome itself invents no note. A policy-permitted no-response result
records the observation and then opens UX-A01 as a distinct effect approval.
No-automatic policy and consumed `once` schedule another internal review
without a message. The `every` soft cap opens UX-D01.

The question-mark tree asks in order whether the target explicitly reported
completion, explicitly declined, supplied meaningful progress, or supplied
any response. A confirmed yes selects the matching visible row; confirmed no
to all four selects no response. Uncertainty at a node shows bounded history
and returns unresolved.

## UX-D04 — Delegation outcome reconciliation

A refusal does not silently restore human execution:

```text
@bc "Bento Camargo" refused responsibility for
#rfr "Review the financial report".

What should happen?

[t]ake it back
[r]eassign...
[a]rchive or supersede Work...
[l]ater
[?] I don't know

[/] more...
```

`later` preserves active coverage and the attributed refusal while deferring
only this review. Take-back previews exact scope, restored human eligibility,
and every pending effect to reject:

```text
Take responsibility back?

Work: #rfr "Review the financial report"
From: @bc "Bento Camargo"
Human work becomes eligible again: yes
Approved but undelivered messages rejected: 1
Optional take-back message: not sent

[y]es    [n]o    [?] I don't know
```

After yes, an optional action may open a separately approved take-back effect.
Reassign selects a new target and shows inherited scope, policy, and review
delay as editable. Its final yes terminates the old record and creates one new
proposed Delegation atomically; human execution remains eligible until the new
handoff. Pending old effects are rejected in that same preview.

Reported completion first lists every still-open fact in the exact delegated
coverage. While anything remains open it offers review open work, keep the
Delegation active, or take it back; it cannot mark the tree closed. Once the
ordinary Nature-owned closure facts are valid, one combined preview applies
the existing Brick or scope completion and terminates the Delegation as
completed. Archive or supersede similarly reuses the existing Work preview and
closes the Delegation as cancelled only in the accepted combined mutation.

## UX-I01 — Text input

```text
Why is this blocked?

› Waiting for production access_

[Enter] confirm · [Esc] cancel

────────────────────────────────────────
text is local draft until confirmed
. #rrsr "Review Rock Splitter rules"
  Orbit › R&D › Rock Splitter
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

## UX-I02 — Feed input

The persistent stacked footer remains visible. The prior `next` proposal becomes a
navigation checkpoint while text is edited:

```text
Feed Little Ant

Tip: prefer English for consistent titles and search.

› comprar leite_

[Enter] continue · [Esc] back

────────────────────────────────────────
. <root>
  <no Domain>
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 0 bricks, 0 raws, 0 reviews
  mode: dumb, focus: idle
```

Enter commits one Raw to the derived Inbox without classification and then
revalidates the suspended useful envelope under UX-047. Escape restores the
exact proposal and random cursor shown before Feed was opened. The tip is
advisory and, under `UX-049`, appears beside every dumb-mode free-text input
rather than only on Feed. Single-key choice screens omit it. Until Enter, the
text remains only a local draft; this guarantee is behavioral and is not
rendered in the footer.

There is no Feed receipt screen. From an existing proposal or focus, the
revalidated screen gains this one-use fact above its footer:

```text
Fed: +cl "comprar leite"
```

It does not replace or answer the primary question. From UX-E00, the first Raw
is the only useful opportunity, so the same commit proceeds directly to
UX-T01 with no intermediate acknowledgment.

## UX-T01 — Raw triage

```text
Review raw material

+milk "milk"

Is this something you could work on by itself?

[y]es    [n]o    [s]kip    [?] I don't know

[/] more...

────────────────────────────────────────
. <root>
  <no Domain>
. Fed: Mon, Aug 3, 08:58
       Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

The `+` handle was allocated with the Raw at Feed time. It is not a `#` Brick
handle and does not make the Raw Work. `yes` enters Nature, optional Template,
structure, duplicate, and local importance settlement before creating Work.
`no` opens UX-T02. `skip` records only a typed triage deferral and leaves the
Raw in the Inbox. Question mark asks whether seeing this exact Raw alone under
`Work:` would communicate a useful action such as doing, considering, or
reading it. Yes returns to Work materialization and no to UX-T02. A second
uncertainty may inspect the complete Raw once and repeat the question; another
leaves triage pending. Escape records nothing and restores the prior useful
envelope.

## UX-T02 — Ranked existing destinations

```text
Does +milk "milk" belong with any of these?

*[1] #bg "Buy groceries"
     living checklist

 [2] Books
     raw shelf

 [3] Technical articles
     raw shelf

 [4] #ibbq "Implement BBQ on Rock Splitter"
     work

 [k]eep as standalone raw material
 [m]ore matches...
 [s]earch...
 [c]reate a new group...
 [?] I don't know

[/] menu...

────────────────────────────────────────
. <root>
  <no Domain>
. Fed: Mon, Aug 3, 08:58
       Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

The factory default is present only when the leading candidate has defensible
recorded evidence under FED-007. `more matches` pages additional existing
candidates without changing the ranking. `search` opens typed autocomplete
across all compatible existing destinations. `create a new group` opens
UX-T03 without asserting anything about unseen candidates. The slash label is
`menu` only to distinguish the command palette from candidate expansion.
`keep` records a standalone disposition and removes the Raw from the Inbox
without creating, linking, shelving, archiving, or completing anything.

From the idle lottery, acceptance renders:

```text
Kept as standalone raw material:

+milk "milk"

[n]ext    [/] more...
```

The result performs no draw. If triage temporarily interrupted a current
focus, the same fact appears once on that focus continuation instead.

## UX-T03 — Create a new group

```text
Create a new group for +milk "milk"

How should this group behave?

[l]ist
    Show its items together as one working unit.

[s]helf
    Organize raw material without turning it into Work.

[w]ork group
    Let its children appear independently in next.

[?] I don't know

[/] more...

────────────────────────────────────────
. <root>
  <no Domain>
. Fed: Mon, Aug 3, 08:58
       Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

`group` is interface language, not a canonical kind. List asks whether the
group should remain available after every current item is resolved, thereby
resolving `living_checklist` versus `finite_checklist`, then asks for its name
and complete Brick preview. Shelf asks for a RawShelf name and preview. Work
group enters ordinary Nature and structure discovery for independently
focusable child Bricks. Escape returns to UX-T02; no branch creates an object
before its final preview.

## UX-T04 — Raw under an ordinary Brick

```text
+aen "API error notes"

Should Little Ant suggest this independently as Work
within #ibbq "Implement BBQ on Rock Splitter"?

[y]es    [n]o    [?] I don't know

[/] more...

────────────────────────────────────────
. #ibbq "Implement BBQ on Rock Splitter"
  Orbit › R&D › Rock Splitter
. Fed: Mon, Aug 3, 08:58
       Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

`yes` enters child-Work materialization with one validated Nature and local
sibling importance position. `no` proposes a typed Raw attachment to the
selected Brick. Neither path treats the Brick as a generic folder.

## UX-T05 — Open ListEntry duplicate and quantity

```text
A similar list item already exists:

Milk
Within: #bg "Buy groceries"
State: open
Existing quantity: 1
Fed quantity: 1

What should happen?

*[k]eep it as is
 [a]dd the fed quantity        1 + 1 → 2
 [c]hange the quantity...
 [s]eparate item...
 [?] I don't know

[/] more...

────────────────────────────────────────
. #bg "Buy groceries"
  Personal › Housekeeping
. Last changed: Mon, Aug 3, 08:10
            Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

`separate item` first edits or otherwise distinguishes the proposed entry; it
does not silently create an indistinguishable duplicate. For a resolved or
cancelled match, the equivalent screen replaces `keep` with `reuse and reopen`
and states that the prior outcome remains in history. The add row appears only
when both quantities use the same MOD-063 normalized unit. A different unit
offers keep, change, or distinguishable separation and never conversion.

## UX-T06 — Assisted recent-Raw proposal

```text
Suggested organization

+milk "milk"
+coffee "coffee"
+bread "bread"

Add these as list items to #bg "Buy groceries"?

*[y]es    [n]o    [s]kip    [?] I don't know

Suggestion: powered up

[/] more...

────────────────────────────────────────
. <root>
  <no Domain>
. Oldest feed: Mon, Aug 3, 08:56
           Now: Mon, Aug 3, 09:00
. 18 bricks, 9 raws, 3 reviews
  mode: powered up, by: /bin/claude-fast.sh, focus: idle
```

The canonical payload enumerates each source Raw and proposed ListEntry,
duplicate, and quantity result. `no` returns to UX-T01 for the originally
selected Raw. `skip` defers only that selected Raw. Neither action resolves or
penalizes any other member of the proposed batch.

## UX-T07 — Raw-to-Work draft

After Nature, optional Template, and their required configuration are
resolved, the canonical title is editable. A deterministic source-derived
value starts selected:

```text
Brick title

Source: +fabow "fix a bug on website"

› Fix a bug on website_

[Enter] continue    [Esc] back

Tip: write Brick titles in English.
```

If recorded evidence supplies compatible parent candidates, the next screen
appears; otherwise the draft remains at root and the final preview says so:

```text
Place this Work:

*[1] within #ws "Website"
 [r]oot
 [s]earch...
 [?] I don't know
```

Search uses ordinary Brick autocomplete and excludes invalid parents. A
selected parent may supply Domain proposal evidence but no membership. When
one or more Domain candidates exist, a bounded multi-selector follows:

```text
Select zero or more Domains:

*[1] Orbit › Website
 [2] Personal › Projects
 [n]o Domain
 [s]earch...
 [?] I don't know

[Enter] continue
```

Number keys toggle rows; `no Domain` clears them; Enter accepts the visible
set. With no candidate the screen is omitted and the final preview says
`Domains: none`. Edit from that preview can still open both complete selectors.

When sibling evidence leaves an unresolved slot, insertion renders the draft
without pretending it already has a handle:

```text
Is this proposed Work

"Fix a bug on website"

      more important than

#aco "Add checkout observability"
?

[m]ore important    [l]ess important
[s]kip              [?] I don't know

[/] more...
```

Every answer remains in the materialization checkpoint until UX-T09 commits.
The first skip redraws with the nearby alternative when one exists. If none
exists, IMP-046 supplies provisional placement and continues rather than
repeating an unanswerable question.

## UX-T08 — Existing-Work suspicion

```text
Similar Work already exists:

#fabow "Fix a bug on website"

Proposed Work:
"Fix a bug on website"
Source: +fabow "fix a bug on website"

Would completing the existing Work also handle this intention?

[u]se existing Work
[c]reate separate Work
[s]how differences
[?] I don't know

[/] more...
```

Use existing attaches the preserved Raw as materialization source and creates
no Brick, handle, or importance evidence. Create separate resumes the draft;
equal titles remain allowed. Show differences is read-only. Question mark asks
the displayed completion question once after that inspection; repeated
uncertainty leaves the materialization pending. No `merge` action appears
because the proposed Brick does not yet exist.

Acceptance renders one compact relationship result:

```text
+fabow "fix a bug on website" now supports
#fabow "Fix a bug on website"

[n]ext    [/] more...
```

The result performs no draw and follows the same current-focus preservation
rule as every other accepted triage disposition.

## UX-T09 — Atomic Work preview and result

```text
Create this Work?

Source: +fabow "fix a bug on website"
Title: "Fix a bug on website"
Nature: atomic task
Template: none
Parent: #ws "Website"
Domains: Orbit › Website
Importance: below #aco "Add checkout observability"
            above #dui "Document the user interface"
Confidence: human comparison

Raw material remains preserved.

*[y]es    [e]dit    [n]o    [?] I don't know

[/] more...
```

Every applicable required configuration, lazy non-human claim, and provisional
confidence reason appears in the same preview. `edit` returns to the nearest
selected fact; `no` discards only the Work draft and returns the source Raw to
UX-T01; reverse navigation retains the draft. Yes is the sole mutation and
allocates the handle only after revalidation.

```text
Created:

#fabow "Fix a bug on website"
From: +fabow "fix a bug on website"
Importance: between #aco and #dui

[n]ext    [/] more...
```

The result performs no draw. If Raw triage was opened transactionally while
another Brick remained current, this block appears once as a compact fact on
the sober current-focus continuation instead of displacing that focus.

## UX-P01 — Habit consequence

```text
This will record an unfulfilled swimming opportunity
and end a 2-occurrence streak.

Continue?

[y]es · *[n]o · [?] I don't know

────────────────────────────────────────
[x][x][-][x][x] · current window ends Sunday
. #stpw "Swim twice per week"
  <no Domain>
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

An ordinary defer-only skip never opens this confirmation or claims the streak
has ended.

## UX-L00 — List-item lifecycle and collector

An incompatible Structure request first asks only the mechanical distinction:

```text
#bg "Buy groceries"

Should this list remain available after all current items are closed?

[y]es    [n]o    [?] I don't know

[/] more...
```

`yes` means a continuing `living_checklist`; `no` means one completable
`finite_checklist`. Question mark asks `Do you expect to add new items after
this current set?` and maps yes/no to the same two rows. A second uncertainty
shows both consequences once, then returns unresolved to Structure. No choice
has a dumb default.

After any required WRK-112 reconciliation, or immediately for a compatible
empty owner, the collector is:

```text
List items for #bg "Buy groceries"

Enter one item per line.
Examples: Milk · 2 x Milk · 1.5 kg x Rice

› Milk
  2 x Coffee
  1.5 kg x Rice
  _

Empty Enter reviews the batch. Esc goes back.

Tip: write in English when possible.
```

The preview renders `Label`, `Amount`, and `Unit` separately for every parsed
line, so an accidental quantity parse can be edited before commit. It applies
owner-scoped duplicate review before exposing yes. A compatible add uses the
ordinary batch preview; a reclassifying add composes the complete behavior
change and entries in one confirmation. One entry is enough. No entry or
Nature change becomes durable before that final yes.

## UX-L01 — Checklist surface family

The same row composition has explicitly different manager, proposal, and run
grammars. A Structure-origin manager is:

```text
List items:

#bg "Buy groceries"

Open: 3    Resolved: 12    Cancelled: 1

> [1] Milk
  [2] Coffee × 2
  [3] Rice · 1.5 kg

[d]one item    [a]dd item    [e]dit item
[c]ancel item  [r]eopen...   [/] more...

────────────────────────────────────────
. <root>
  Personal › Housekeeping
. Last changed: Mon, Aug 3, 08:58
           Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

Up/Down and `1..9` only move the visible selection. `done item`, edit, and
cancel target that row; reopen opens the same local selector over closed rows.
Direct resolution outside a run records the entry outcome but fabricates no
run. Ordinary `/show` and `/history` expose older closed rows. There is no
ListEntry handle or bespoke history command.

The ordinary lottery proposal is:

```text
Work:

#bg "Buy groceries"

Open items: 3

  [1] Milk
  [2] Coffee × 2
  [3] Rice · 1.5 kg

Focus?

[y]es    [s]kip    [?] I don't know
[/] more...
```

This proposal deliberately has no direct `done`: accepting starts or resumes
the owner run, while item resolution and finite-scope completion remain
distinct honest actions. Skip retains the checklist variant's typed skip
semantics.

The active run is:

```text
Current focus:

#bg "Buy groceries"

> [1] [ ] Milk
  [2] [x] Coffee × 2
  [3] [ ] Rice · 1.5 kg

[d]one item    [a]dd item    [f]inish run
[s]kip         [/] more...

────────────────────────────────────────
. <root>
  Personal › Housekeeping
. Run started: Mon, Aug 3, 08:40
           Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: #bg
```

`done item` changes the selected open row immediately without a confirmation
or receipt. Closed rows remain in their run-local positions until finish. Add
uses one collector line and owner-scoped duplicate review, then returns with
the new open row selected. Finish is unavailable until an item mutation has
committed; the educational recovery points to `/pause`, skip, or back.

A partial finish reports resolved, cancelled, and still-open counts, clears
focus, applies cooldown, and waits at `[n]ext    [/] more...`. A living owner
with zero open entries additionally says it is now dormant. A finite owner
with zero open entries transitions to the existing scope-closure review:

```text
Review:

#tc "Prepare for the trip"

No list items are open.
Resolved: 8    Cancelled: 2

What should happen?

[d]one    [a]dd more work
[s]kip    [?] I don't know

[/] more...
```

Nothing is preselected, including a cancelled-only scope. Leaving or skipping
preserves the typed review for a later weighted draw; it does not make the
empty checklist executable. Adding an entry invalidates the review. Completing
the checklist is a separate reversible mutation after the run finish.

Large lists retain this composition with a nine-row viewport, exact counts,
Up/Down and PageUp/PageDown. Search results show the owner, entry label, and
state, then open this surface with the row selected rather than inventing a
global entry sigil.

## UX-E00 — Pristine first start

This screen exists only before Little Ant has any Brick, Raw material, or
import candidate:

```text
No Bricks yet.

Feed Little Ant its first raw material to get started.

[f]eed   [/] more...

────────────────────────────────────────
. <root>
  <no Domain>
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 0 bricks, 0 raws, 0 reviews
  mode: dumb, focus: idle
```

Feed opens UX-I02. More may expose import, help, configuration, and exit when
those actions are valid. The screen does not manufacture a Brick and is not
used merely because the forecast has no eligible work.

## UX-E01 — Useful empty state

```text
Nothing is actionable in the current scope.

What next?

*[b]lockers
[w]aits
[c]hange Domain
[f]eed something
[e]nd for now
[?] I don't know

────────────────────────────────────────
4 active · 3 blocked · 1 not before tomorrow
. <root>
  Orbit › R&D › Rock Splitter
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 4 bricks, 2 raws, 3 reviews
  mode: dumb, focus: idle
```

The available choices derive from actual state; the screen never fabricates
work merely to avoid emptiness.

## Surface mapping

| Canonical element | REPL | Web/mobile | Operator skill |
|---|---|---|---|
| primary block | terminal text | text/card with same order | same text block |
| action | one key, no Enter | button/touch target retaining label and shortcut | natural language or canonical letter mapped to the same action ID |
| secondary region | stacked footer below a divider | separated stacked footer | separated block after the prompt |
| input | line editor | text field | free text |
| revision | carried by harness | hidden transport value | included in tool action |

No surface may replace the canonical question with its own summary.
The table is evaluated only after the dumb REPL flow and its powered-up delta
have been accepted.

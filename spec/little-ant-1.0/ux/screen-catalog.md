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
route revalidates it before anything may act on the old proposal.

## UX-RF01 — Typed Brick autocomplete

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
the pending interaction permits only an existing target. Typing `@` opens the
equivalent person-or-company search from UX-075; its creation row is always
`New person or company...`. UUIDv7 values are available in technical
projections but never appear in this ordinary selector.

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

`yes` focuses and starts WIP. `skip` opens UX-S01. `?` opens UX-H01 without
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
compact label. `?` shows the entire selected path, alternatives at branching
nodes, and recorded probabilities without redrawing.

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
may expose `drop`, `supersede`, history, and inspection without crowding the
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
context. Reopening a child, `drop`, and `supersede` remain contextual-palette
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
⬇️ [l]ess important
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

Enter preserves the draft and runs the ordinary duplicate, Nature, optional
Template, and importance-insertion route without committing partial domain
state. Because an editor is active, Backspace deletes and Left Arrow moves the
cursor. The keypress that deletes the final character leaves the empty editor
open; another Backspace while already empty, or Escape, returns to UX-S02A
under UX-019.

## UX-S04 — Dumb enabling structure

After the pending Feed resolves `#ratpl`, dumb mode applies FED-030:

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
navigation restores the preceding pending Feed checkpoint. No Brick,
Dependency, symptom, cooldown, or comparison is durable until the complete
reaction succeeds atomically.

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

Selecting `[c]hange subject` on UX-S07 opens one uncommitted target choice:

```text
#rrsr "Review Rock Splitter rules"

What would you rather work on?

[1] Orbit › R&D › Field Operations
[2] Orbit › Platform
[3] Personal › Little Ant
[4] Personal › Housekeeping

[m]ore options...
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
excluded. Every alternative spells its complete Domain path because a
subcontext may make sense only within its ancestors and identical leaf names
may exist in different branches. The dumb screen has no default.

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
accepted focus. `?` explains this inference and returns. Escape, empty-state
Backspace, or Left Arrow restores UX-S07 or the previous page without symptom,
cooldown, signal, focus change, active-Domain change, or draw. Multi-Domain,
no-Domain, and no-target recovery remain explicit release boundaries.

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

`?` opens UX-K02. No selection is a hidden fallback and no Template appears
on this screen. Each example is illustrative UI copy, not input to
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
Feed pending rather than creating a Brick.

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

`yes` accepts the Nature and continues Feed. `no` returns to UX-K01 with the
original input preserved. `?` restarts UX-K02 at Q0. Escape
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
Feed input and enters UX-K01; no Nature, Template, or ranking evidence is
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
installed catalog has no compatible Template, Feed skips this screen and
continues with the resolved Nature.

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

After `[b]reak it into parts`, dumb mode collects pending titles continuously:

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
`review` only after two parts exist and then opens UX-B01. The title hint is
visually dim. Reverse navigation from an already empty input restores the
preceding pending-part checkpoint without semantic undo or durable state.

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
directly to UX-B00 without a weak or decorative proposal.

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

## UX-B01 — Break an atomic task

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
its Nature, creates every child and its handle atomically, and installs the
displayed low-confidence sibling order without interposing importance
questions. The parent then stops appearing as ordinary Work while incomplete
children exist. Completing the final child releases a parent-scope review; it
does not silently complete or immediately refocus the parent.

`edit` restores UX-B00 with all drafts. `no` discards them and restores UX-S06
or the direct-command origin without recording `big`, break, or any other
evidence. Escape, Backspace, and Left Arrow restore UX-B00 with the drafts
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
and applies review cooldown. `?` may expose the complete sibling run, its
entered or assisted source, applicable evidence, and why this pair is
unresolved; it never answers. Reverse navigation preserves the pending review.

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

## UX-A01 — External-effect confirmation

When an external-effect approval is selected by the ordinary lottery:

```text
Send this follow-up?

Suggested message:

“Hi Bento, could you share an update on
#rrsr "Review Rock Splitter rules"?”

[y]es    [e]dit    [n]o    [l]ater    [s]kip
[?] I don't know

────────────────────────────────────────
👤 Bento Camargo
delegation follow-up · due 2 days ago
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

────────────────────────────────────────
👤 Bento Camargo
delegation follow-up · due 2 days ago
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

Enter begins the deterministic Feed route. Escape restores the exact proposal
and random cursor shown before Feed was opened. The tip is advisory and, under
`UX-049`, appears beside every dumb-mode free-text input rather than only on
Feed. Single-key choice screens omit it. Until Enter, the text remains only a
local draft; this guarantee is behavioral and is not rendered in the footer.

## UX-H01 — Contextual uncertainty

```text
What would help you decide?

[c]ontext
[w]hy this appeared
[r]elated Bricks
[a]sk me questions
[s]uggest an answer
[?] Little Ant help

────────────────────────────────────────
no answer or skip has been recorded
. <root>
  <no Domain>
. Workday: Mon, Aug 3
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

Closing assistance restores the same pending revision.

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

## UX-L01 — Living checklist

```text
#bg "Buy groceries"

Open items

[ ] Milk
[ ] Coffee
[ ] Dish soap

Start this run?

[y]es · [d]one · [s]kip · [?] I don't know

────────────────────────────────────────
3 open
. <root>
  Personal › Housekeeping
. Last run: Tue, Jul 28, 09:00
          Now: Mon, Aug 3, 09:00
. 18 bricks, 7 raws, 3 reviews
  mode: dumb, focus: idle
```

All open entries appear together. `done` is interpreted through the
living-checklist Nature and cannot silently retire the standing Brick.

## UX-E00 — Pristine first start

This screen exists only before Little Ant has any Brick, Raw material, or
import candidate:

```text
No Bricks yet.

Feed Little Ant its first Brick to get started.

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

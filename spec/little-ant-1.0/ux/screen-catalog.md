# Canonical screen catalog

These are normative English reference compositions. Terminal width may wrap
long paths, but renderers preserve the content order and action order.

## Shared composition

```text
<primary subject or complete preview>

<concrete question>

<canonical actions>

<secondary command escape>

----------------------------------------
<optional Within path>
<optional Domain/current-Domain context>
<at most one warning and overflow count>
<optional subject-specific facts>
<persistent bottom status bar>
```

Empty secondary rows are omitted. Context and status rows are contiguous.
Emoji have accessible textual equivalents. Markdown code blocks show the
monochrome structure: a capable terminal applies UX-070..073, including dim
brackets and dividers, bold cyan shortcut characters, and reverse video for
the command-palette selection. Styled and plain renderings occupy the same
display-cell columns.

## UX-R00 — Dumb REPL frame

The REPL opens by restoring or obtaining `next`, not by waiting for a command.
The status bar follows the divider and contextual rows rather than occupying
the top of the screen:

```text
Work:

#rrsr "Review Rock Splitter rules"

Focus?

[y]es    [s]kip    [?] I don't know
[/] more...

----------------------------------------
↳ #rs "Rock Splitter"
🏷️ Orbit › R&D › Rock Splitter
🐜 Little Ant   18 eligible   3 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: idle
```

The automatically served envelope, secondary-command escape, context panel,
and bottom status bar are all part of REPL UX. `[?] I don't know` belongs to
the current Focus decision, while `[/] more...` opens UX-M01. Adaptive or
narrow-terminal rendering may fold regions but cannot test only the inner
envelope and call that a REPL simulation.

Powered-up mode reuses the frame and changes only:

```text
   Mon, Aug 3   09:00         mode: powered up · by: /bin/claude-fast.sh   focus: idle
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

----------------------------------------
↳ #rs "Rock Splitter"
🏷️ Orbit › R&D › Rock Splitter
🐜 Little Ant   18 eligible   3 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: idle
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

At 02:00 on Tuesday, the status bar keeps the real civil date. If the
configured workday began at 06:00, it exposes the differing operational label
instead of silently displaying Monday as though it were the calendar date:

```text
🐜 Little Ant   18 eligible   3 reviews
   Tue, Aug 4   02:00         workday: Mon, Aug 3   mode: dumb   focus: idle
```

A habit opportunity still belonging to Monday may add:

```text
🐜 Monday slot · closes Tue, Aug 4 at 04:00 America/Montevideo (UTC-03)
```

An exact event remains exact and zoned regardless of either operational
boundary:

```text
✈️ Tue, Aug 4 · 02:30 · America/Sao_Paulo (UTC-03)
```

## UX-F01 — Focus

```text
Work:

#wtms "Write the migration specification"

Focus?

[y]es    [s]kip    [?] I don't know
[/] more...

----------------------------------------
↳ #rlav2 "Recover Little Ant v1"
🏷️ Personal › Little Ant
⚠️ #smr "Submit migration report" · deadline in 2h · +2 warnings
🐜 Little Ant   18 eligible   3 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: idle
```

`yes` focuses and starts WIP. `skip` opens UX-S01. `?` opens UX-H01 without
consuming another draw. Direct completion remains available as `/done` in
UX-M01. Pressing unbound `n` gives the educational UX-062 result and restores
this same opportunity without mutation.

## UX-F02 — Cross-Domain focus

```text
Work:

#bg "Buy groceries"

Focus?

[y]es    [s]kip    [?] I don't know
[/] more...

----------------------------------------
🏷️ Personal › Housekeeping
   from Orbit › R&D › Rock Splitter
🐜 Little Ant   18 eligible   3 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: idle
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

----------------------------------------
↳ #rlav2 "Recover Little Ant v1"
🏷️ Personal › Little Ant
🚧 reached through #rlav "Release Little Ant v1"
   → blocked by #rio "Restore importance ordering"
   → blocked by this Brick
🐜 Little Ant   18 eligible   3 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: idle
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

----------------------------------------
↳ #rs "Rock Splitter"
🏷️ Orbit › R&D › Rock Splitter
🐜 Little Ant   17 eligible   3 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: #rrsr
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

----------------------------------------
↳ #rs "Rock Splitter"
🏷️ Orbit › R&D › Rock Splitter
🐜 Little Ant   17 eligible   3 reviews
   Mon, Aug 3   09:05         mode: dumb   focus: #rrsr
```

This continuation creates no event, performs no draw, and selects no
microcopy. Before the configured stale-focus boundary, it does not ask
`Still on this?`. The eventual stale-focus review is a separate opportunity
under `WRK-004`, not a decoration of this screen.

## UX-F07 — Immediate focused completion

Pressing `d` on UX-F04 or UX-F05 does not open a confirmation:

```text
Done:

#rrsr "Review Rock Splitter rules"

🎉 Nice work. That Brick is in place.

[n]ext   [/] more...

----------------------------------------
↳ #rs "Rock Splitter"
🏷️ Orbit › R&D › Rock Splitter
🐜 Little Ant   17 eligible   3 reviews
   Mon, Aug 3   09:32         mode: dumb   focus: idle
```

The phrase is one `work_completed` entry from the 16-phrase factory catalog.
The contextual palette makes `/undo` available against the typed completion
event, and `Left Arrow` opens UX-U01 because no provisional backward
checkpoint remains. The REPL does not draw automatically from this result.
Pressing `n` invokes the ordinary canonical `next` pipeline; closing the REPL
instead leaves focus idle, and the next startup follows UX-046.

## UX-U01 — Contextual undo preview

Pressing `Left Arrow` after local backward navigation is exhausted does not
silently cross the commit boundary:

```text
Undo the last recorded action?

✅ Completed:
#rrsr "Review Rock Splitter rules"

[y]es   [n]o   [?] I don't know

[/] more...

----------------------------------------
↳ #rs "Rock Splitter"
🏷️ Orbit › R&D › Rock Splitter
🐜 Little Ant   17 eligible   3 reviews
   Mon, Aug 3   09:32         mode: dumb   focus: idle
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

----------------------------------------
↳ #rs "Rock Splitter"
🏷️ Orbit › R&D › Rock Splitter
🐜 Little Ant   17 eligible   3 reviews
   Mon, Aug 3   09:32         mode: dumb   focus: #rrsr
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

----------------------------------------
↳ #rs "Rock Splitter"
🏷️ Orbit › R&D › Rock Splitter
🐜 Little Ant   18 eligible   3 reviews
   Mon, Aug 3   09:05         mode: dumb   focus: idle
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

----------------------------------------
↳ #rtnw "Release the new website"
Suggestion: /bin/claude-fast.sh · importance insertion
🐜 Little Ant   18 eligible   3 reviews
   Mon, Aug 3   09:00         mode: powered up · by: /bin/claude-fast.sh   focus: idle
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

----------------------------------------
↳ #rs "Rock Splitter"
🏷️ Orbit › R&D › Rock Splitter
⚠️ #rfi "Review fraud incident" · deadline tomorrow
served after 9 days · active Domain unchanged
🐜 Little Ant   18 eligible   3 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: #rrsr
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

----------------------------------------
↳ #rs "Rock Splitter"
🏷️ Orbit › R&D › Rock Splitter
⚠️ #rfi "Review fraud incident" · deadline tomorrow
served after 9 days · active Domain unchanged
🐜 Little Ant   18 eligible   3 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: #rrsr
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

----------------------------------------
↳ #rs "Rock Splitter"
🏷️ Orbit › R&D › Rock Splitter
🐜 Little Ant   18 eligible   3 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: #rrsr
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

----------------------------------------
↳ #rs "Rock Splitter"
🏷️ Orbit › R&D › Rock Splitter
🐜 Little Ant   18 eligible   3 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: #rrsr
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

----------------------------------------
↳ #rs "Rock Splitter"
🏷️ Orbit › R&D › Rock Splitter
🐜 Little Ant   18 eligible   3 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: #rrsr
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

----------------------------------------
↳ #rs "Rock Splitter"
🏷️ Orbit › R&D › Rock Splitter
🐜 Little Ant   18 eligible   3 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: #rrsr
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

Waiting since Mon, Aug 3 · reviewed 4 days ago

What happened?

[r]esponse received    [w]ait longer
[f]ollow up             [c]hange what is blocking it
[s]kip                  [?] I don't know

[/] more...

----------------------------------------
↳ #rs "Rock Splitter"
🏷️ Orbit › R&D › Rock Splitter
🐜 Little Ant   17 eligible   3 reviews
   Fri, Aug 7   09:00         mode: dumb   focus: idle
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

----------------------------------------
↳ #rs "Rock Splitter"
🏷️ Orbit › R&D › Rock Splitter
🐜 Little Ant   18 eligible   3 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: #rrsr
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

----------------------------------------
🐜 Little Ant   18 eligible   3 reviews
   Mon, Aug 3   09:03         mode: dumb   focus: #rrsr
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

----------------------------------------
↳ #rs "Rock Splitter"
🏷️ Orbit › R&D › Rock Splitter
🐜 Little Ant   18 eligible   3 reviews
   Mon, Aug 3   09:07         mode: dumb   focus: idle
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

----------------------------------------
🐜 Little Ant   0 eligible    0 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: idle
```

`?` opens UX-K02. No selection is a hidden fallback and no Template appears
on this screen. Each example is illustrative UI copy, not input to
classification or Template selection.

## UX-K02 — Guided Nature discovery

```text
"Fix a bug on website"

Will completing this once finish the whole intention?

[y]es    [n]o    [?] I don't know

----------------------------------------
🐜 Little Ant   0 eligible    0 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: idle
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

----------------------------------------
🐜 Little Ant   0 eligible    0 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: idle
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

----------------------------------------
🐜 Little Ant   0 eligible    0 reviews
   Mon, Aug 3   09:00         mode: powered up · by: /bin/claude-fast.sh   focus: idle
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

----------------------------------------
🐜 Little Ant   0 eligible    0 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: idle
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

----------------------------------------
🐜 Little Ant   0 eligible    0 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: idle
```

No category screen is introduced while this flat choice remains usable.
Future categories or pagination must follow `UX-056` and preserve the same
Template identities.

## UX-B01 — Break an atomic task

```text
#ptqr "Prepare the quarterly report"

This Brick is an atomic task.
Independently tracked parts require a different Nature.

Change Nature:
    atomic task › project

Proposed structure:

#ptqr "Prepare the quarterly report"     project
├─ #ctqd "Collect the quarterly data"    atomic task
├─ #atr "Analyze the results"            atomic task
└─ #wtfr "Write the final report"        atomic task

Apply this change?

[y]es    [n]o    [?] I don't know

----------------------------------------
🏷️ Orbit › Finance › Quarterly reporting
🐜 Little Ant   18 eligible   3 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: idle
```

If the proposed parts should render and complete together, the preview offers
`finite_checklist`; an open-ended independently focusable set offers
`collection`. Content-only notes keep `atomic_task`. The operation preserves
the parent identity and commits no child before confirmation.

## UX-A01 — External-effect confirmation

When an external-effect approval is selected by the ordinary lottery:

```text
Send this follow-up?

"Hi Bento, could you confirm whether the review is complete?"

*[y]es    [n]o    [l]ater    [s]kip
[?] I don't know

----------------------------------------
👤 Bento Camargo
delegation follow-up · due 2 days ago
🐜 Little Ant   18 eligible   3 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: idle
```

`later` opens a date screen and records nothing until the absolute date is
confirmed. When this confirmation was selected by the ordinary lottery,
`skip` preserves the pending effect and records only typed approval deferral,
cooldown, and future pressure. A confirmation reached directly rather than by
the lottery omits `skip` unless its own domain grammar independently permits
deferral.

## UX-I01 — Text input

```text
Why is this blocked?

› Waiting for production access_

[Enter] confirm · [Esc] cancel

----------------------------------------
↳ #rrsr "Review Rock Splitter rules"
text is local draft until confirmed
🐜 Little Ant   18 eligible   3 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: idle
```

## UX-I02 — Feed input

The persistent status bar remains visible. The prior `next` proposal becomes a
navigation checkpoint while text is edited:

```text
Feed Little Ant

Tip: prefer English for consistent titles and search.

› comprar leite_

[Enter] continue · [Esc] back

----------------------------------------
🐜 Little Ant   0 eligible    0 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: idle
```

Enter begins the deterministic Feed route. Escape restores the exact proposal
and random cursor shown before Feed was opened. The tip is advisory and, under
`UX-049`, appears beside every dumb-mode free-text input rather than only on
Feed. Single-key choice screens omit it. Until Enter, the text remains only a
local draft; this guarantee is behavioral and is not rendered as status text.

## UX-H01 — Contextual uncertainty

```text
What would help you decide?

[c]ontext
[w]hy this appeared
[r]elated Bricks
[a]sk me questions
[s]uggest an answer
[?] Little Ant help

----------------------------------------
no answer or skip has been recorded
🐜 Little Ant   18 eligible   3 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: idle
```

Closing assistance restores the same pending revision.

## UX-P01 — Habit consequence

```text
This will record an unfulfilled swimming opportunity
and end a 2-occurrence streak.

Continue?

[y]es · *[n]o · [?] I don't know

----------------------------------------
↳ #stpw "Swim twice per week"
[x][x][-][x][x] · current window ends Sunday
🐜 Little Ant   18 eligible   3 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: idle
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

----------------------------------------
🏷️ Personal › Housekeeping
3 open · last run 6 days ago
🐜 Little Ant   18 eligible   3 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: idle
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

----------------------------------------
🐜 Little Ant   0 eligible    0 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: idle
```

Feed opens UX-I02. More may expose import, help, configuration, and exit when
those actions are valid. The screen does not manufacture a Brick and is not
used merely because the eligible count is zero.

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

----------------------------------------
🏷️ Orbit › R&D › Rock Splitter
4 active · 3 blocked · 1 not before tomorrow
🐜 Little Ant   0 eligible    3 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: idle
```

The available choices derive from actual state; the screen never fabricates
work merely to avoid emptiness.

## Surface mapping

| Canonical element | REPL | Web/mobile | Operator skill |
|---|---|---|---|
| primary block | terminal text | text/card with same order | same text block |
| action | one key, no Enter | button/touch target retaining label and shortcut | natural language or canonical letter mapped to the same action ID |
| secondary region | context plus bottom status below a divider | separated context/status panel | separated block after the prompt |
| input | line editor | text field | free text |
| revision | carried by harness | hidden transport value | included in tool action |

No surface may replace the canonical question with its own summary.
The table is evaluated only after the dumb REPL flow and its powered-up delta
have been accepted.

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
brackets and dividers, bold green shortcut characters, and reverse video for
the command-palette selection. Styled and plain renderings occupy the same
display-cell columns.

## UX-R00 — Dumb REPL frame

The REPL opens by restoring or obtaining `next`, not by waiting for a command.
The status bar follows the divider and contextual rows rather than occupying
the top of the screen:

```text
Next:

#r12345 "Review Rock Splitter rules"

Focus?

[y]es    [s]kip    [?] I don't know
[/] more...

----------------------------------------
↳ #p12345 "Rock Splitter"
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

/done       Mark #r12345 "Review Rock Splitter rules" as done
/feed       Feed Little Ant
/show       Inspect #r12345 "Review Rock Splitter rules"
/history    Open interaction history

Type to filter available commands.
↑/↓ select · Enter run · Esc back

----------------------------------------
↳ #p12345 "Rock Splitter"
🏷️ Orbit › R&D › Rock Splitter
🐜 Little Ant   18 eligible   3 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: idle
```

Only currently valid commands participate in search. The initial suggestions
are contextual and replay-deterministic. Descriptions expose the current
target rather than relying on a hidden argument. Escape restores UX-R00
unchanged. `/show` returns to it; `/done` resolves it; a completed `/feed`
route revalidates it before anything may act on the old proposal.

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
Next:

#c12345 "Write the migration specification"

Focus?

[y]es    [s]kip    [?] I don't know
[/] more...

----------------------------------------
↳ #a12345 "Recover Little Ant v1"
🏷️ Personal › Little Ant
⚠️ #u11111 "Submit migration report" · deadline in 2h · +2 warnings
🐜 Little Ant   18 eligible   3 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: idle
```

`yes` focuses and starts WIP. `skip` opens UX-S01. `?` opens UX-H01 without
consuming another draw. Direct completion remains available as `/done` in
UX-M01. Pressing unbound `n` gives the educational UX-062 result and restores
this same opportunity without mutation.

## UX-F02 — Cross-Domain focus

```text
Next:

#h12345 "Buy groceries"

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
Next:

#b30000 "Define the importance-maintenance contract"

Focus?

[y]es    [s]kip    [?] I don't know
[/] more...

----------------------------------------
↳ #a12345 "Recover Little Ant v1"
🏷️ Personal › Little Ant
🚧 reached through #r90000 "Release Little Ant v1"
   → blocked by #i20000 "Restore importance ordering"
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

#r12345 "Review Rock Splitter rules"

💪 Nice! Roll up your sleeves and give it a go.
Come back when you're done—or when something gets in the way. 😌

[d]one   [s]kip   [/] more...

----------------------------------------
↳ #p12345 "Rock Splitter"
🏷️ Orbit › R&D › Rock Splitter
🐜 Little Ant   17 eligible   3 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: #r12345
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

#r12345 "Review Rock Splitter rules"

[d]one   [s]kip   [/] more...

----------------------------------------
↳ #p12345 "Rock Splitter"
🏷️ Orbit › R&D › Rock Splitter
🐜 Little Ant   17 eligible   3 reviews
   Mon, Aug 3   09:05         mode: dumb   focus: #r12345
```

This continuation creates no event, performs no draw, and selects no
microcopy. Before the configured stale-focus boundary, it does not ask
`Still on this?`. The eventual stale-focus review is a separate opportunity
under `WRK-004`, not a decoration of this screen.

## UX-F07 — Immediate focused completion

Pressing `d` on UX-F04 or UX-F05 does not open a confirmation:

```text
Done:

#r12345 "Review Rock Splitter rules"

🎉 Nice work. That Brick is in place.

[/] more...

----------------------------------------
↳ #p12345 "Rock Splitter"
🏷️ Orbit › R&D › Rock Splitter
🐜 Little Ant   17 eligible   3 reviews
   Mon, Aug 3   09:32         mode: dumb   focus: idle
```

The phrase is one `work_completed` entry from the 16-phrase factory catalog.
The contextual palette makes `/undo` available against the typed completion
event. This result does not yet settle whether the REPL subsequently draws
another opportunity automatically.

## UX-F06 — Paused focus result

Selecting `/pause` from a current-focus palette commits immediately:

```text
Paused:

#r12345 "Review Rock Splitter rules"

This Brick remains in progress.

[/] more...

----------------------------------------
↳ #p12345 "Rock Splitter"
🏷️ Orbit › R&D › Rock Splitter
🐜 Little Ant   18 eligible   3 reviews
   Mon, Aug 3   09:05         mode: dumb   focus: idle
```

The completed focus interval is history, but there is no `paused` Brick state,
skip evidence, cooldown, Domain change, personality phrase, or automatic
draw. The contextual palette remains anchored to the displayed WIP Brick.

## UX-C01 — Importance comparison

```text
#a12345 "Launch the landing page"

    is more important than

#b45678 "Interview prospective customers"

Is that right?

*[y]es · [n]o · [s]kip
[?] I don't know

----------------------------------------
↳ #p12345 "Release the new website"
Suggestion: /bin/claude-fast.sh · importance insertion
🐜 Little Ant   18 eligible   3 reviews
   Mon, Aug 3   09:00         mode: powered up · by: /bin/claude-fast.sh   focus: idle
```

The `*` appears only when evidence supports that default. `no` records the
reverse strict relation; it never means equality.

## UX-S01 — Served-work symptom

```text
#r12345 "Review Rock Splitter rules"

What's getting in the way?

💭 [v]ague / 🧗 [h]ard / 🏔️ bi[g]
⏳ [w]aiting / 🚧 [b]locked
🥱 [t]ired / 😐 bo[r]ed / 😨 [f]ear
📥 [n]ot important now
🧩 [o]ther
❓ [?] I don't know

Already finished?

✅ [d]one

----------------------------------------
↳ #p12345 "Rock Splitter"
🏷️ Orbit › R&D › Rock Splitter
⚠️ #u11111 "Review fraud incident" · deadline tomorrow
served after 9 days · active Domain unchanged
🐜 Little Ant   18 eligible   3 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: idle
```

Selecting a symptom opens its separate reaction screen without recording
evidence. Escape from the reaction screen restores this exact symptom screen;
Escape here restores the exact Focus screen. Only the final reaction commits
the symptom and reaction together. An explicit `skip anyway` reaction commits
the symptom, cooldown, and no additional remediation.

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
#a12345 "Prepare the quarterly report"

This Brick is an atomic task.
Independently tracked parts require a different Nature.

Change Nature:
    atomic task › project

Proposed structure:

#a12345 "Prepare the quarterly report"        project
├─ #c12345 "Collect the quarterly data"       atomic task
├─ #n12345 "Analyze the results"              atomic task
└─ #w12345 "Write the final report"           atomic task

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

```text
Send this follow-up?

"Hi Bento, could you confirm whether the review is complete?"

*[y]es · [n]o · [l]ater
[?] I don't know

----------------------------------------
👤 Bento Camargo
delegation follow-up · due 2 days ago
🐜 Little Ant   18 eligible   3 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: idle
```

`later` opens a date screen and records nothing until the absolute date is
confirmed.

## UX-I01 — Text input

```text
Why is this blocked?

› Waiting for production access_

[Enter] confirm · [Esc] cancel

----------------------------------------
↳ #r12345 "Review Rock Splitter rules"
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
↳ #s12345 "Swim twice per week"
[x][x][-][x][x] · current window ends Sunday
🐜 Little Ant   18 eligible   3 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: idle
```

An ordinary defer-only skip never opens this confirmation or claims the streak
has ended.

## UX-L01 — Living checklist

```text
#h12345 "Buy groceries"

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

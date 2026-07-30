# Canonical screen catalog

These are normative English reference compositions. Terminal width may wrap
long paths, but renderers preserve the content order and action order.

## Shared composition

```text
<primary subject or complete preview>

<concrete question>

<canonical actions>

<global actions>

----------------------------------------
<optional Within path>
<optional Domain/current-Domain context>
<at most one warning and overflow count>
<optional subject-specific facts>
<persistent bottom status bar>
```

Empty secondary rows are omitted. Context and status rows are contiguous.
Emoji have accessible textual equivalents.

## UX-R00 — Dumb REPL frame

The REPL opens by restoring or obtaining `next`, not by waiting for a command.
The status bar follows the divider and contextual rows rather than occupying
the top of the screen:

```text
Next:

#r12345 "Review Rock Splitter rules"

Focus?

[y]es    [d]one       [s]kip    [?] I don't know
[f]eed   [/] more...

----------------------------------------
↳ #p12345 "Rock Splitter"
🏷️ Orbit › R&D › Rock Splitter
🐜 Little Ant   18 eligible   3 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: idle
```

The automatically served envelope, global-action row, context panel, and
bottom status bar are all part of REPL UX. `[f]eed` opens UX-I02; it is not
preselected. `[?] I don't know` belongs to the current Focus decision, while
`[/] more...` opens the secondary-action and command palette. Adaptive or
narrow-terminal rendering may fold regions but cannot test only the inner
envelope and call that a REPL simulation.

Powered-up mode reuses the frame and changes only:

```text
   Mon, Aug 3   09:00         mode: powered up · by: /bin/claude-fast.sh   focus: idle
```

plus any explicitly attributed proposals that passed the startup handshake.

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

[y]es    [d]one       [s]kip    [?] I don't know
[f]eed   [/] more...

----------------------------------------
↳ #a12345 "Recover Little Ant v1"
🏷️ Personal › Little Ant
⚠️ #u11111 "Submit migration report" · deadline in 2h · +2 warnings
🐜 Little Ant   18 eligible   3 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: idle
```

`yes` focuses and starts WIP. `done` completes directly. `skip` opens UX-S01.
`?` opens UX-H01 without consuming another draw.

## UX-F02 — Cross-Domain focus

```text
Next:

#h12345 "Buy groceries"

Focus?

[y]es    [d]one       [s]kip    [?] I don't know
[f]eed   [/] more...

----------------------------------------
🏷️ Personal › Housekeeping
   from Orbit › R&D › Rock Splitter
🐜 Little Ant   18 eligible   3 reviews
   Mon, Aug 3   09:00         mode: dumb   focus: idle
```

There is no preliminary `Switch Domain?`. `yes` starts focus and changes the
active Domain atomically; `done` and `skip` preserve it.

## UX-F03 — Focus reached through blockers

```text
Next:

#b30000 "Define the importance-maintenance contract"

Focus?

[y]es    [d]one       [s]kip    [?] I don't know
[f]eed   [/] more...

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
🐜 importance insertion · powered-up suggestion
```

The `*` appears only when evidence supports that default. `no` records the
reverse strict relation; it never means equality.

## UX-S01 — Served-work symptom

```text
#r12345 "Review Rock Splitter rules"

What's getting in the way?

💭 [v]ague / 🧗 [h]ard / 🏔️ bi[g]
⏳ [w]aiting / 🚧 bloc[k]ed
🥱 [t]ired / 😐 [b]ored / 😨 [f]ear
📥 [n]ot important now
🧩 [o]ther
❓ [?] I don't know

Already finished?

✅ [d]one

----------------------------------------
↳ #p12345 "Rock Splitter"
🏷️ Orbit › R&D › Rock Splitter
⚠️ #u11111 "Review fraud incident" · deadline tomorrow
🐜 served after 9 days · active Domain unchanged
```

Selecting a symptom records evidence and opens a separate reaction screen.
Escape before selection returns to the exact Focus screen without a skip.

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
original input preserved. `?` restarts UX-K02 at its first question. Escape
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
   Mon, Aug 3   09:00         mode: powered up · focus: idle
```

The skill uses the same confirmation envelope. `no` restores the unchanged
Feed input and enters UX-K01; no Nature, Template, or ranking evidence is
accepted from the rejected proposal.

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

## UX-A01 — External-effect confirmation

```text
Send this follow-up?

"Hi Bento, could you confirm whether the review is complete?"

*[y]es · [n]o · [l]ater
[?] I don't know

----------------------------------------
👤 Bento Camargo
🐜 delegation follow-up · due 2 days ago
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
🐜 text is local draft until confirmed
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
and random cursor shown before `[f]eed`. The tip is advisory and specific to
dumb mode. Until Enter, the text remains only a local draft; this guarantee is
behavioral and is not rendered as status text.

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
🐜 no answer or skip has been recorded
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
🐜 [x][x][-][x][x] · current window ends Sunday
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
🐜 3 open · last run 6 days ago
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

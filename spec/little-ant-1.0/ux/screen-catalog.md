# Canonical screen catalog

These are normative English reference compositions. Terminal width may wrap
long paths, but renderers preserve the content order and action order.

## Shared composition

```text
<persistent status bar>

<primary subject or complete preview>

<concrete question>

<canonical actions>

----------------------------------------
<optional Within path>
<optional Domain/current-Domain context>
<at most one warning and overflow count>
<ant recap, provenance, or discreet review state>

<global actions>
```

Empty secondary rows are omitted. Emoji have accessible textual equivalents.

## UX-R00 — Dumb REPL frame

The REPL opens by restoring or obtaining `next`, not by waiting for a command.
The status bar is bounded product chrome rather than main content:

```text
┌────────────────────────────────────────────────────────────┐
│ 🐜 Little Ant · Mon, Aug 3 · 09:00                        │
│ mode: dumb · focus: idle · 18 eligible · 3 reviews        │
└────────────────────────────────────────────────────────────┘

Next:

#r12345 "Review Rock Splitter rules"

Focus?

[y]es · [d]one · [s]kip · [?] I don't know

----------------------------------------
↳ #p12345 "Rock Splitter"
🏷️ Orbit > R&D > Rock Splitter
🐜 selected by next · active Domain continuity

[f]eed · [/] commands
```

The status bar, automatically served envelope, context panel, and global-action
footer are all part of REPL UX. `[f]eed` opens UX-I02; it is not preselected.
`[?] I don't know` belongs to the current Focus decision, while `[/] commands`
opens the command palette. Adaptive or narrow-terminal rendering may fold
regions but cannot test only the inner envelope and call that a REPL
simulation.

Powered-up mode reuses the frame and changes only:

```text
mode: powered up · by: /bin/claude-fast.sh
```

plus any explicitly attributed proposals that passed the startup handshake.

## UX-F01 — Focus

```text
Next:

#c12345 "Write the migration specification"

Focus?

[y]es · [d]one · [s]kip · [?] I don't know

----------------------------------------
↳ #a12345 "Recover Little Ant v1"
🏷️ Personal > Little Ant
⚠️ #u11111 "Submit migration report" · deadline in 2h · +2 warnings
🐜 18 eligible · 3 reviews
```

`yes` focuses and starts WIP. `done` completes directly. `skip` opens UX-S01.
`?` opens UX-H01 without consuming another draw.

## UX-F02 — Cross-Domain focus

```text
Next:

#h12345 "Buy groceries"

Focus?

[y]es · [d]one · [s]kip · [?] I don't know

----------------------------------------
🏷️ Personal > Housekeeping
   from Orbit > R&D > Rock Splitter
🐜 unrelated work retained a positive chance
```

There is no preliminary `Switch Domain?`. `yes` starts focus and changes the
active Domain atomically; `done` and `skip` preserve it.

## UX-F03 — Focus reached through blockers

```text
Next:

#b30000 "Define the importance-maintenance contract"

Focus?

[y]es · [d]one · [s]kip · [?] I don't know

----------------------------------------
↳ #a12345 "Recover Little Ant v1"
🏷️ Personal > Little Ant
🐜 drew #r90000 "Release Little Ant v1"
   → blocked by #i20000 "Restore importance ordering"
   → blocked by this Brick
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
🏷️ Orbit > R&D > Rock Splitter
⚠️ #u11111 "Review fraud incident" · deadline tomorrow
🐜 served after 9 days · active Domain unchanged
```

Selecting a symptom records evidence and opens a separate reaction screen.
Escape before selection returns to the exact Focus screen without a skip.

## UX-K01 — Nature choice

```text
How should #n12345 "Buy groceries" behave?

*[s]tanding checklist
[f]inite checklist
[c]ollection
[o]ther templates
cus[t]om
[?] I don't know

----------------------------------------
🐜 suggested from the standard template catalog
```

The exact shortcuts remain subject to `OPEN-UX-001`; the word and ordering are
the canonical content to validate.

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

> Waiting for production access_

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

> comprar leite_

[Enter] continue · [Esc] back

----------------------------------------
🐜 original text is preserved · nothing has been recorded
```

Enter begins the deterministic Feed route. Escape restores the exact proposal
and random cursor shown before `[f]eed`.

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

## UX-P01 — Practice consequence

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

## UX-L01 — Standing checklist

```text
#h12345 "Buy groceries"

Open items

[ ] Milk
[ ] Coffee
[ ] Dish soap

Start this run?

[y]es · [d]one · [s]kip · [?] I don't know

----------------------------------------
🏷️ Personal > Housekeeping
🐜 3 open · last run 6 days ago
```

All open entries appear together. `done` is interpreted through the
standing-checklist Nature and cannot silently retire the standing Brick.

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
🏷️ Orbit > R&D > Rock Splitter
🐜 4 active · 3 blocked · 1 not before tomorrow
```

The available choices derive from actual state; the screen never fabricates
work merely to avoid emptiness.

## Surface mapping

| Canonical element | REPL | Web/mobile | Operator skill |
|---|---|---|---|
| primary block | terminal text | text/card with same order | same text block |
| action | one key, no Enter | button/touch target retaining label and shortcut | natural language or canonical letter mapped to the same action ID |
| secondary region | separated footer/status | separated context panel | separated block after the prompt |
| input | line editor | text field | free text |
| revision | carried by harness | hidden transport value | included in tool action |

No surface may replace the canonical question with its own summary.
The table is evaluated only after the dumb REPL flow and its powered-up delta
have been accepted.

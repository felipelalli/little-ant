# 24. Deterministic REPL harness

## 24.1 Release requirement and role

The REPL is required for Little Ant 1.0. Its working public command is:

```text
la repl
```

It is the primary guided interface, not a thin line reader or a launcher for
unrelated commands. It behaves like a deterministic operator or harness:

- it observes the current state;
- it invokes the same canonical command pipeline as the CLI;
- it presents the result;
- it receives the next human action;
- it advances through mechanical steps until the next human decision boundary.

The default dumb REPL contains no AI and makes no semantic judgment. An
optional powered-up mode may consult an external model adapter under the rules
in section 24.9. It does not change core authority.

The REPL may use a shared in-process command runner rather than spawning a
subprocess, but every confirmed action must have the same observable domain
semantics, validation, persistence, and automatic tick behavior as the
equivalent CLI command.

The harness may automate deterministic plumbing. It must never accept a human
default, approve an external action, or record a semantic answer with human
authority on the user's behalf. Powered-up mode may submit only those
explicitly attributed, low-authority AI operations that the core marks safe
for configured automatic use.

The dumb REPL, powered-up REPL, and operator skill consume the same
state-scoped interaction envelope. Mode changes the source of proposals, not
the available domain actions.

Pack-based UIAdapters also consume that envelope. They extend where an
interaction is rendered, not what the interaction means. The first-party REPL
remains a core surface and is not required to load itself as a Pack.

The REPL is also the reference interaction design for future first-party web
and mobile surfaces and for operator behavior. Those consumers preserve its
domain prompts, action meanings, information hierarchy, and progressive
disclosure. They adapt physical controls and layout to the channel rather than
copying terminal escape sequences or terminal geometry.

## 24.2 Input model

Every finite-choice interaction executes with one keypress and no Enter:

- menu selection;
- yes/no/skip and comparison answers;
- navigation;
- context-valid commands on the main screen.

Free text uses an explicit line-editing mode:

- Enter confirms;
- Escape cancels and restores the prior state;
- ordinary command hotkeys do not steal characters while text is being edited.

Navigation reversal and semantic reversal are distinct:

- `Escape` cancels or closes the current uncommitted screen and returns to its
  prior screen without recording an event;
- `Backspace` remains text deletion and is not semantic undo;
- `C-_` is the canonical one-key REPL binding for semantic undo;
- `C-M-_` is the canonical one-key REPL binding for semantic redo;
- `/undo` and `/redo` expose the same operations through the command palette;
- `C-z`, `C-y`, and `C-S-z` are not rebound because terminal suspension,
  yank, and terminal key-encoding ambiguity must remain unsurprising.

For example, pressing `s` from `Focus?` merely opens the symptom screen.
Pressing `Escape` there returns to the same pending `Focus?` interaction
without recording a skip. Once a symptom is selected, undo is semantic: the
core appends a compensating event and restores that interaction without
consuming another forecast draw.

Ordinary undo is scoped to the current interaction and reverses its latest
reversible semantic action. Reversing an action from another session, surface,
or device requires explicitly selecting its event through a working core
surface such as `la undo <event-id>`. Redo reapplies the compensated intent
only when it remains valid against the current domain revision; otherwise the
core reports a conflict. An external effect is never silently reversed:
compensation, when possible, is a new separately approved effect.

The remaining exact key grammar and shortcut letters remain open.

Visible choices use one consistent shortcut typography:

```text
- [s]kip
- [c]hange subject
- [?]
```

The shortcut character appears at its actual position in the English label.
When a later character is required to avoid a collision, the brackets remain
inside the word, as in `e[x]change`; a renderer must not invent an unrelated
prefix such as `[x] exchange`. An exceptional label with no usable character
may use a `?` fallback such as `[?] dunno`, but the interaction design should
avoid needing it. Exact collision resolution and the relationship with the
uncertainty `?` remain open. Shortcut uniqueness is screen-local: reusing `n`
on another screen is valid when it selects the `[n]` embedded in that screen's
label.

Response letters form one stable product language across interaction variants
and rendering channels. When applicable:

```text
[y]es · [n]o · [d]one · [s]kip · [?]
```

- `y` confirms the concrete proposition currently displayed;
- `n` rejects it;
- `d` records completion of the cited Brick;
- `s` skips without recording an answer to the proposition;
- `?` expresses uncertainty and opens contextual decision assistance without
  answering.

An interaction omits inapplicable actions rather than reusing their letters
with another meaning. `n` appears only when rejecting the displayed proposition
is semantically distinct from skipping the opportunity. `Focus?` therefore
uses `y/d/s/?`: adding `n` would duplicate the explicit served-work skip.
Another proposition such as `Send this follow-up?` may use `y/n/s/?` when
rejection and deferral have distinct canonical effects.

A prospective Domain transition does not add a preliminary yes/no screen. The
ordinary `Focus?` prompt may display the active and candidate Domains. `y`
starts focus and changes the active Domain atomically; `d` completes without
changing it; `s` skips the Brick and preserves the active Domain; `?` explains
the transition and forecast evidence.

Pressing `s` for served work opens one bounded symptom screen with several
applicable choices visible together. The screen does not present remediation
actions as if they were symptoms. After a symptom is selected, another
interaction may propose appropriate reactions. Every screen follows the same
in-word shortcut typography. Similar symptoms may share a visual row, for
example `[v]ague / [h]ard / bi[g]`, while remaining separate one-key choices.

The working symptom screen is:

```text
What's getting in the way?

- [v]ague / [h]ard / bi[g]
- [w]aiting / bloc[k]ed
- [t]ired / [b]ored / [f]ear
- [n]ot important now
- [o]ther
- [?] I don't know

Already finished?

- [d]one
```

`waiting` reports an unresolved external person, event, or condition with no
known direct action now. `blocked` reports an actionable missing prerequisite
such as another Brick, information, access, or material. Selecting `blocked`
may lead to a later proposal to create or connect an enabling Brick, but the
symptom selection does not perform that reaction. The repeated `done` action
records only completion and produces no skip evidence, cooldown, or pressure.

`?` is visible and labeled on every finite-choice loop, normally as
`[?] I don't know`. It means uncertainty about the pending human decision, not
generic system help. It opens a contextual assistance screen that may reveal
information, ask diagnostic questions, compare relevant examples, or present
attributed suggestions, then restores the same pending interaction without an
answer or skip event. Inside that assistance screen, another `?` opens Little
Ant system help. Therefore `??` is the effective system-help gesture. Exact
labels and assistance-screen actions remain open.

A guided decision renders the concrete domain question rather than an abstract
operation heading. For example, an importance comparison asks whether one
cited Brick is more important than the other and offers directional
`yes`/`no`, `skip`, and `?` responses. The main prompt need not contain a
prominent `Why` block when the question is self-explanatory. Its provenance
remains in the interaction envelope and under `?`; an adaptive layout may
surface a compact reason summary unobtrusively in a status region.

For a pending `next` suggestion, `?` is also the only top-level entry point for
opening its wider context. It may expose the explanation, ancestor path,
project or collection context, children, blockers, evidence, and contextual
navigation actions. The ordinary prompt therefore needs no separate
`open project` shortcut. All relevant context remains reachable through
bounded and paginated progressive disclosure rather than an unbounded JSON or
history dump. Leaving that view restores the exact same pending suggestion
without consuming randomness or recording a semantic action.

In navigation mode, `/` opens a command palette containing only commands that
are valid in the current state. Typing filters command names and descriptions.
Choosing a command starts a guided argument dialog. While editing text, `/` is
a literal character.

The earlier idea of using `:` for this surface is superseded. Whether the
palette also accepts exact raw command syntax, and how its selection keys work,
remain open.

The command palette and every guided prompt are rendered from the core's
currently valid actions rather than a second REPL-owned command catalog.

The same boundary applies to `next`: the core exposes a versioned closed set of
focus-opportunity variants and their valid actions. The REPL never turns that
set into a generic `interaction` command and no UIAdapter or Pack may append a
new fundamental variant.

## 24.3 Command transparency

For every semantic action, the REPL shows:

1. the exact canonical command represented by the action, such as `$ la …`;
2. the exact result produced by the canonical `human` renderer;
3. the next result, prompt, or decision boundary.

Implementation-only plumbing such as an internal `--json` flag is omitted from
the displayed command. This makes the guided flow teach the canonical CLI
without leaking transport details.

## 24.4 Adaptive terminal layout

On a capable interactive terminal, the REPL uses an alternate screen with
persistent regions:

- header and compact status;
- rotating informational notices and reminders;
- recent activity;
- main result, prompt, or transcript;
- footer with keys valid for the current state.

The main interaction region contains only its primary subject, concrete
question, and valid answers. Parentage, Domain, warnings, provenance, and
compact statistics belong to a visually separate context region below it.
They do not compete with the pending decision.

Composition and Domain paths both render from broadest to most specific.
Empty rows are omitted. The context region shows at most one warning and an
additional-warning count; the warning-selection policy remains open. Compact
statistics occupy at most one line and use the Little Ant mascot rather than
a generic chart marker. A working focus layout is:

```text
#c12345 "Write the migration specification"

Focus?

[y]es · [d]one · [s]kip · [?]

----------------------------------------
↳ #a12345 "Recover Little Ant v1"
🏷️ Personal > Little Ant
⚠️ #u11111 "Submit migration report" · deadline in 2h · +2 warnings
🐜 18 eligible · 3 reviews
```

Icons are renderer-owned markers, not title content or entity identity. A
capable renderer may use the confirmed emoji presentation; every layout also
has an equivalent accessible no-emoji or ASCII fallback.

On a limited terminal it falls back to an inline transcript with a redrawn
compact status. Both layouts have identical semantics and key bindings. The
terminal must be restored after normal exit, interruption, and errors.

The core exposes one typed canonical status summary. Plain `la status` renders
its compact canonical human line; there is no separate `--line` flag.
Structured status access returns the canonical `human` value and the
command-appropriate sparse projection by default. The REPL may explicitly
request the complete typed StatusSummary required by its persistent regions;
this remains another projection of the same facts, not a second status model.

The alternate-screen header and inline fallback consume the typed fields
directly. They may arrange those fields for their available space, but they do
not parse the compact line or define a second set of status facts. The operator
skill surfaces the canonical human line rather than independently composing
counts.

Pending approvals, follow-ups, and reviews remain visible in this status region
without interrupting the main result solely because of their kind:

```text
🐜 1 approval pending · 2 reviews · focus idle
```

They participate in the same weighted draw as executable work and questions.
If another kind wins, the counts remain visible. A genuinely pending
interaction or active current focus resumes before a new draw because it is
already in progress, not because its variant has a privileged rank.

Exact region sizes, resize behavior, color use, accessibility behavior, and
the terminal UI library remain open. Exact status fields, field order,
wording, timestamp policy, and zero-omission rules are also open.

See
[Structured command responses and sparse projections](33-structured-command-responses-and-sparse-projections.md)
for the confirmed general presence rules. Status-specific field selection and
meaningful-zero rules remain open.

## 24.5 Recent activity and history

The main screen shows a small number of recent semantic actions. Each entry is
one concise line containing:

- time;
- actor or origin;
- outcome;
- a summary of the affected work.

Multiple domain events emitted by one command appear as one action. Raw event
JSON is not shown in the ordinary activity view.

`/history` opens the complete semantic activity ledger with scrolling and
search. Closing it restores the exact previous dialog state. The full
transcript of the current REPL session belongs to the UI checkpoint; it is not
copied forever into the domain event log.

The canonical CLI must also expose paginated and composable history queries so
an operator never needs to load the entire event log into model context.
Filters should cover at least time, Brick or related entity, scope, actor,
event or semantic-action family, and importance/relevance. A concise
state-derived brief may summarize a selected range while retaining references
that permit exact drill-down.

The metadata needed to group events into one user action and the exact
transcript retention limit, filter grammar, relevance model, and brief format
remain open.

## 24.6 Timed notices

Informational time events update only the notice region. An event requiring a
decision waits until the current prompt or text edit reaches a safe screen
boundary; it never interrupts an answer in progress.

Dismissing a notice acknowledges only its current occurrence. Snoozing is a
separate operation with an explicit deadline. A later recurrence may produce
a new notice.

Date notices follow the idempotent threshold semantics in
[Dates and urgency](11-dates-and-urgency.md). An acknowledged or snoozed
notice does not alter the underlying Brick date or its forecast pressure.

Idle tick cadence, notice rotation, and the exact interaction with recurrence
remain open.

## 24.7 Exact dialog recovery

The REPL persists enough UI state to recover the exact dialog after a clean
shutdown or crash, including:

- current screen and prompt;
- draft text buffer and cursor position;
- navigation position;
- current-session transcript;
- the event-log cursor and integrity hash against which the dialog was built.

This checkpoint is stored atomically in a separate file adjacent to the domain
data. It is presentation state, not part of the append-only domain event log.
Confirmed semantic actions remain authoritative in that log.

An unsubmitted text buffer is therefore not a draft Brick description or
another canonical field. The REPL must not autosave it into domain content.
Only an explicit confirmation invokes the corresponding canonical operation.
Previously confirmed portions survive through ordinary events; unconfirmed
text may be recovered only under checkpoint rules.

On startup:

- if the log still matches, restore the dialog exactly;
- if the log has advanced, validate and rebase the checkpoint;
- if the prompt remains valid, restore it against the new state;
- otherwise preserve the draft in a recovery area and present an explicit
  conflict choice.

A keypress received for a stale prompt must never be applied to a different
prompt.

Checkpoint naming, retention, size limits, cleanup, and multi-device conflict
behavior remain open.

The cross-surface interaction rules, derived-prompt behavior, and honest
progress contract are defined in
[Resumable interactions and honest progress](31-resumable-interactions-and-honest-progress.md).

## 24.8 Non-interactive and integration boundaries

The ordinary CLI remains the canonical scriptable surface. Exact behavior when
`la repl` has no interactive TTY remains open; it must not silently switch to
unsafe one-key semantics.

Outbound messages or side effects still follow the ordinary approval boundary.
The REPL may guide and display them, but its harness role does not broaden
authority.

## 24.9 Powered-up mode

The REPL may be started with an external model adapter, using a working surface
such as:

```text
la repl --power-up "~/bin/claude-fast.sh"
```

The exact flag and path grammar remain open. The adapter:

- must be an explicitly selected executable;
- receives every prompt through standard input, never a size-limited command
  argument;
- is validated once before the REPL starts with a small structured handshake;
- causes startup to fail clearly if execution, timeout, parsing, or handshake
  validation fails;
- returns one bounded structured response under a versioned schema;
- is never trusted to produce a canonical event or command directly.

The harness may tolerate cheap-model framing text around an intended
structured object only through a bounded, deterministic extraction and schema
validation rule. Ambiguous, multiple, malformed, or unsupported objects are
rejected rather than guessed.

The status region always exposes the mode and adapter:

```text
mode: dumb
mode: powered up · by: /bin/claude-fast.sh
```

Powered-up mode may propose:

- English normalization while preserving original text;
- a title, parent, BrickNature, template, or ListEntry target;
- semantic duplicate candidates;
- attributed AI comparison evidence or provisional placement;
- a likely pattern behind repeated skips or practice failures;
- an enabling Brick, dependency, schedule adjustment, or other explicit
  proposal.

All such output remains attributed AI judgment. The core validates it against
the same allowed actions returned to the dumb REPL and skill. Powered-up mode
must not fabricate human evidence, bypass external-action approval, silently
merge work, or automatically finalize an unfulfilled practice opportunity.
Configured safe operations may include canonical translation or AI-authored
provisional comparison evidence without a separate confirmation, provided the
result is visible in history, remains reversible through ordinary correction,
and can never displace applicable human judgment.

For importance placement specifically, powered-up mode may answer bounded
binary-insertion comparisons before the user sees a placement prompt. The core
performs the insertion and marks the result as provisional. A non-blocking
recent-activity or status summary may report what was placed, where, and by
which adapter; full comparison evidence remains available in history and
inspection. The user is asked later only when human validation or
recalibration becomes useful. Dumb mode and adapter abstention use the same
core insertion flow but ask the human directly.

## 24.10 Template-assisted feeding

The REPL uses the same feeding-route and template-candidate envelope as the
operator skill. Powered-up mode may rank a bounded core-provided shortlist and
suggest a concrete target, template version, and validated inputs. It does not
invent a hidden nature or send arbitrary template code.

After rejection, or immediately in dumb mode, the REPL presents compatible
routes and templates as one-key choices. The user may open categorized,
searchable, paginated `other templates` or choose `custom` to enter the
capability-guided builder. The final shortcuts come from the core grammar.

This fallback is not a degraded semantic path: it reaches the same canonical
operations and resolved configuration, only with more explicit human choices.
The catalog is queried progressively, so neither a cheap model nor an operator
skill needs the complete library in prompt context.

## 24.11 Experience parity

The three guided modes should feel like one product:

- the same status, recent activity, history, prompts, and shortcuts;
- the same exact canonical command transparency;
- the same recovery and approval behavior;
- the same provenance shown for defaults and proposals.

Powered-up operation should mainly reduce mechanical questions and provide
better defaults. It remains less semantically capable than a full operator
skill running inside Codex or Claude.

## 24.12 Pack-based UI surfaces

Little Ant 1.0 includes `UIAdapter` as a typed executable PackComponent.
Alternate surfaces such as Telegram, Slack, Discord, Matrix, voice, web,
mobile, or another TUI may render the same canonical InteractionEnvelope
without introducing a second command catalog.

A UIAdapter receives the interaction identity and revision, canonical content,
currently valid action IDs, commands, shortcuts, and contextual help. It may
translate these into channel buttons, keyboards, pages, speech, or layout. A
received response maps back to exactly one action ID and the revision against
which it was displayed. The core rejects stale or out-of-scope replies.

Transport sessions, delivery receipts, pagination cursors, and draft input are
surface-local checkpoint state. They do not become domain events merely
because the surface runs remotely. A configured personal UI channel may
deliver ordinary interaction, while messages to other recipients, publishing,
and unrelated notifications remain explicit external effects.

UIAdapters run through the same isolated Lua Pack runner and credential broker
as other executable components. They cannot invent actions or shortcuts,
weaken approvals, retain tokens, or claim that a transport-generated response
has human authority. Exact initial adapters, transport checkpoint schemas,
offline behavior, delivery retry rules, and conformance fixtures remain open.

See
[Lua Pack runtime, credentials, exporters, and UI adapters](34-lua-pack-runtime-credentials-exporters-and-ui-adapters.md).

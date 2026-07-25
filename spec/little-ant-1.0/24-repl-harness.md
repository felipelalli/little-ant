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
- it captures the next human action;
- it advances through mechanical steps until the next human decision boundary.

The REPL contains no AI and makes no semantic judgment. It may use a shared
in-process command runner rather than spawning a subprocess, but every
confirmed action must have the same observable domain semantics, validation,
persistence, and automatic tick behavior as the equivalent CLI command.

The harness may automate deterministic plumbing. It must never accept a
suggested default, approve an external action, or answer a semantic question
on the user's behalf.

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

The exact key grammar and shortcut letters remain open.

In navigation mode, `/` opens a command palette containing only commands that
are valid in the current state. Typing filters command names and descriptions.
Choosing a command starts a guided argument dialog. While editing text, `/` is
a literal character.

The earlier idea of using `:` for this surface is superseded. Whether the
palette also accepts exact raw command syntax, and how its selection keys work,
remain open.

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

On a limited terminal it falls back to an inline transcript with a redrawn
compact status. Both layouts have identical semantics and key bindings. The
terminal must be restored after normal exit, interruption, and errors.

Exact region sizes, resize behavior, color use, accessibility behavior, and
the terminal UI library remain open.

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

The metadata needed to group events into one user action and the exact
transcript retention limit remain open.

## 24.6 Timed notices

Informational time events update only the notice region. An event requiring a
decision waits until the current prompt or text edit reaches a safe screen
boundary; it never interrupts an answer in progress.

Dismissing a notice acknowledges only its current occurrence. Snoozing is a
separate operation with an explicit deadline. A later recurrence may produce
a new notice.

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

On startup:

- if the log still matches, restore the dialog exactly;
- if the log has advanced, validate and rebase the checkpoint;
- if the prompt remains valid, restore it against the new state;
- otherwise preserve the draft in a recovery area and present an explicit
  conflict choice.

A keypress captured for a stale prompt must never be applied to a different
prompt.

Checkpoint naming, retention, size limits, cleanup, and multi-device conflict
behavior remain open.

## 24.8 Non-interactive and integration boundaries

The ordinary CLI remains the canonical scriptable surface. Exact behavior when
`la repl` has no interactive TTY remains open; it must not silently switch to
unsafe one-key semantics.

Outbound messages or side effects still follow the ordinary approval boundary.
The REPL may guide and display them, but its harness role does not broaden
authority.

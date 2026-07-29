# 7. Interaction and surface contract

## One product language

- **UX-001 [core] — Canonical envelope.** Every guided surface consumes one
  state-scoped `InteractionEnvelope` containing identity, domain revision,
  screen grammar, canonical English content, valid action IDs, commands,
  shortcuts, help, provenance, and bounded context.
- **UX-002 [core] — Almost-literal parity.** REPL, first-party web/mobile,
  UIAdapters, and operator skill preserve the same wording, punctuation,
  subject order, action order, shortcut letters, emojis, defaults, and screen
  transitions.
- **UX-003 [core] — Permitted adaptation.** A surface may change wrapping,
  density, pagination, physical control, and accessibility representation.
  It may not rename, reorder, omit, combine, or reinterpret canonical actions.
- **UX-004 [core] — REPL reference composition.** The first-party REPL is the
  reference layout and guided-flow harness. Other surfaces render the same
  composition with appropriate click, touch, speech, or natural-language
  controls.
- **UX-005 [core] — Sparse context.** Main content contains the current subject,
  concrete question, and valid answers. Parentage, Domain, warnings,
  provenance, mode, recent activity, and statistics occupy a separated
  secondary region.

## Primary screen grammars

- **UX-006 [core] — Closed grammar family.** Reusable primary screens are:

  ```text
  focus | comparison | confirmation | choice | input
  ```

  A review orchestrates these screens and identifies itself discreetly; it is
  not a sixth primary grammar.

- **UX-007 [core] — Focus.** One served Brick asks `Focus?` and ordinarily
  offers `[y]es · [d]one · [s]kip · [?]`.
- **UX-008 [core] — Comparison.** Two peers and one directional relation ask
  whether the displayed statement is right, using
  `[y]es · [n]o · [s]kip · [?]`.
- **UX-009 [core] — Confirmation.** One complete proposed action or external
  effect is previewed before `[y]es`, `[n]o`, optional contextual `[l]ater`,
  `[s]kip` when semantically valid, and `[?]`.
- **UX-010 [core] — Choice.** Mutually exclusive domain choices show stable
  in-word shortcuts, an optional suggested default, and uncertainty.
- **UX-011 [core] — Input.** Explicit text-editing mode uses Enter to submit
  and Escape to cancel. One-key command shortcuts never steal typed text.

The normative reference renderings live in
[the screen catalog](ux/screen-catalog.md).

## Action grammar

- **UX-012 [core] — One key for finite choice.** Every finite REPL choice
  executes on one keypress without Enter.
- **UX-013 [core] — Letter belongs to word.** The shortcut is the bracketed
  character at its real position, such as `[s]kip`, `[c]hange`, or
  `e[x]change`. A renderer never invents an unrelated prefix letter.
- **UX-014 [core] — Stable meanings.** When applicable:

  ```text
  [y]es | [n]o | [d]one | [l]ater | [s]kip | [?] I don't know
  ```

  Inapplicable actions are omitted rather than reusing a letter with another
  meaning.

- **UX-015 [core] — Suggested default.** `*` marks at most one defensible
  suggested action. Pressing `*` selects it. No evidence means no default.
- **UX-016 [core] — Contextual uncertainty.** `[?] I don't know` is visible in
  every finite decision. It opens assistance for the pending decision and
  then restores the same envelope without an answer or skip event.
- **UX-017 [core] — Nested system help.** Within contextual assistance, another
  `?` opens Little Ant help. Generic help never silently answers the decision.
- **UX-018 [core] — Contextual later.** `[l]ater` exists only for honestly
  deferrable proposals and opens an explicit date choice before recording
  anything.

## Navigation, undo, and commands

- **UX-019 [core] — Navigation is not mutation.** Escape closes or cancels the
  current uncommitted screen and restores the preceding checkpoint without a
  domain event. Backspace remains text deletion.
- **UX-020 [core] — Semantic undo.** `C-_` and `/undo` append a typed
  compensating event for the latest reversible action in the current
  interaction; they never delete history or consume a new draw.
- **UX-021 [core] — Semantic redo.** `C-M-_` and `/redo` reapply the compensated
  intent only if current preconditions still hold. Conflict is explicit.
  External effects require a separately approved compensation.
- **UX-022 [core] — Command palette.** `/` opens a searchable palette of only
  the commands valid in the current state and guides their arguments. In input
  mode `/` is literal text.
- **UX-023 [core] — Grammar inspection.** `la grammar`,
  `la grammar --screen <grammar>`, and `la grammar --json` expose the same
  versioned registry used by all surfaces. The current envelope remains the
  authority for state-valid actions.
- **UX-024 [core] — Command transparency.** A confirmed guided action can show
  the exact canonical CLI command and canonical human result, teaching one
  scriptable language without exposing transport flags.

## Status, history, and recovery

- **UX-025 [core] — Secondary status.** `Within`, Domain, one selected warning
  plus an additional-warning count, mode, and one compact ant-mascot summary
  are visually separated below the main decision. Empty rows are omitted.
- **UX-026 [core] — Discreet warning rotation.** If several warnings apply,
  one is selected replay-deterministically at a screen boundary. Rendering the
  same envelope does not rotate or consume randomness.
- **UX-027 [standard] — Recent action recap.** The main harness shows a short
  list of semantic user actions, grouping multiple domain events emitted by
  one command into one concise line.
- **UX-028 [standard] — Full history.** `/history` opens searchable, paginated
  semantic history and returns to the exact pending screen. CLI filters cover
  time, Brick/entity, scope, actor, semantic family, and relevance.
- **UX-029 [core] — Revision binding.** Every response cites the interaction
  identity and revision it answered. A stale keypress is rejected rather than
  applied to another prompt.
- **UX-030 [core] — Exact capable-surface recovery.** A capable surface may
  atomically checkpoint screen, navigation, transcript, draft buffer, cursor,
  domain revision, and integrity hash outside the event log. Confirmed domain
  facts remain event state.
- **UX-031 [core] — Honest progress.** Exact totals appear only for finite,
  stable, known work. Adaptive reviews show recorded facts or labeled ranges,
  never fictional percentages.
- **UX-032 [core] — Terminal safety.** Alternate-screen terminals restore
  normal state after exit, interruption, or error and provide an equivalent
  inline fallback.

## Dumb and powered-up harness

- **UX-033 [core] — Dumb completeness.** The dumb REPL invokes the same
  canonical pipeline and can complete every required flow without AI.
- **UX-034 [standard] — Explicit powered-up adapter.** A working invocation is
  `la repl --power-up <executable>`. The executable receives prompts only on
  stdin.
- **UX-035 [standard] — Startup handshake.** Before entering the REPL, the host
  sends a bounded versioned structured challenge, enforces execution and parse
  limits, and fails startup if the adapter does not return exactly one valid
  response.
- **UX-036 [standard] — Bounded extraction.** Cheap-model framing text may be
  removed only through a deterministic bounded object extractor. Multiple,
  ambiguous, malformed, or unsupported objects fail rather than being guessed.
- **UX-037 [standard] — Visible mode.** Status always displays `mode: dumb` or
  `mode: powered up · by: <executable>`.
- **UX-038 [standard] — Limited assistance.** Powered-up mode may translate,
  classify, rank bounded candidates, suggest patterns, and contribute
  attributed provisional comparisons. It cannot create canonical events,
  human evidence, external approval, merge, or completion directly.
- **UX-039 [standard] — Skill equivalence.** The operator skill may interpret
  unrestricted natural language more deeply, but renders and advances through
  the same envelope and canonical actions.

## Errors and dry-run

- **UX-040 [core] — Typed educational errors.** Failures include stable codes
  for at least precondition, not found, and ambiguous reference, plus safe
  concrete recovery actions when available.
- **UX-041 [core] — Global dry-run.** Every mutating CLI operation supports
  `--dry-run`, performing ordinary parsing, resolution, validation, tick, and
  deterministic calculation without events, checkpoints, Pack invocation,
  persistent randomness, or external effects.
- **UX-042 [core] — Useful failure ending.** An error leaves the user with a
  concrete correction, bounded search, valid alternative, or explicit safe
  stop; never an unexplained dead end.

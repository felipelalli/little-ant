# 7. Interaction and surface contract

## One product language

- **UX-001 [core] — Canonical envelope.** Every guided surface consumes one
  state-scoped `InteractionEnvelope` containing identity, domain revision,
  screen grammar, canonical English content, valid action IDs, commands,
  shortcuts, help, provenance, and bounded context. The envelope and its
  transitions come from the canonical CLI/protocol command dispatcher, never
  from a surface-local reconstruction of domain rules. When the envelope
  presents a selectable opportunity, one semantic variant discriminant owns
  its required payload and valid actions. The screen grammar is presentation
  reuse, not the opportunity's semantic type.
- **UX-002 [core] — Almost-literal parity.** REPL, powered-up REPL, the
  operator Skill, the shipped local-web UIAdapter, and any future conforming
  mobile surface preserve the same wording, punctuation, subject order, action
  order, shortcut letters, emojis, defaults, and screen transitions.
- **UX-003 [core] — Permitted adaptation.** A surface may change wrapping,
  density, pagination, physical control, and accessibility representation.
  It may not rename, reorder, omit, combine, or reinterpret canonical actions.
- **UX-004 [core] — Dumb REPL reference composition.** The first-party dumb
  REPL is the reference layout and complete guided-flow harness. A screen and
  transition are defined there before powered-up assistance, Skill, or local
  web may claim parity. A future mobile presentation must render the same
  composition with appropriate click, touch, speech, or natural-language
  controls. The REPL captures terminal input, maintains only local editing and
  rendering state, invokes the canonical CLI/protocol, and renders the
  returned envelope. It never writes the event log, recomputes eligibility,
  invents actions, or becomes an integration endpoint for another surface.
- **UX-005 [core] — Sparse context.** Persistent product status, the current
  decision, contextual evidence, and global navigation are separate visual
  regions. Main content contains only the current subject, concrete question,
  and valid contextual answers.

## Primary screen grammars

- **UX-006 [core] — Closed grammar family.** Reusable primary screens are:

  ```text
  focus | comparison | confirmation | choice | input
  ```

  A review orchestrates these screens and identifies itself discreetly; it is
  not a sixth primary grammar.

- **UX-007 [core] — Focus.** One served Brick renders the semantic type heading
  `Work:`, asks `Focus?`, and offers only the primary decision actions
  `[y]es · [s]kip · [?] I don't know`. `Work:` covers every focusable Nature;
  narrower `Task:` and technical `Execution suggestion:` are not canonical
  headings. Less-frequent actions such as direct completion and Feed remain
  reachable through `[/] more...`; they do not compete visually with the
  focus decision.
- **UX-008 [core] — Comparison.** Two peers and one directional relation ask
  the displayed proposition but name both possible directions explicitly. A
  comparison is proposition-led: it begins directly with the natural question
  (`Is` for the canonical importance composition) and has no preceding
  `Next:`, `Importance:`, or generic `Comparison:` heading. Importance uses
  `[m]ore important · [l]ess important · [s]kip · [?] I don't know`.
  Other comparative namespaces use their own equally explicit relation words
  rather than inheriting `yes/no` mechanically.
- **UX-009 [core] — Confirmation.** One complete proposed action or external
  effect is previewed before consequence-named actions whenever those are
  clearer. A genuinely binary proposition may still use natural
  `[y]es · [n]o`; it never contorts `no` into an in-word shortcut such as
  `n[o]`. Optional contextual `[l]ater`, `[s]kip` when semantically valid, and
  `[?]` remain available.
- **UX-010 [core] — Choice.** Mutually exclusive domain choices show stable
  in-word shortcuts, an optional suggested default, and uncertainty.
- **UX-011 [core] — Input.** Explicit text-editing mode uses Enter to submit
  and Escape to cancel. The REPL marks the editable line with `›`; one-key
  command shortcuts never steal typed text. UX-I01 is the canonical
  single-line selected-prefill rendering.

The normative reference renderings live in
[the screen catalog](ux/screen-catalog.md).

## Action grammar

- **UX-012 [core] — One key for finite choice.** Every finite REPL choice
  executes on one keypress without Enter.
- **UX-013 [core] — Letter belongs to word.** The shortcut is the bracketed
  character at its real position, such as `[s]kip`, `[c]hange`, or `bo[r]ed`
  when `[b]locked` already owns the initial in that namespace. A renderer
  never invents an unrelated prefix letter or moves an obvious initial merely
  to pursue artificial cross-screen uniqueness.
- **UX-014 [core] — Stable meanings.** When applicable:

  ```text
  [n]ext | [y]es | [n]o | [d]one | [l]ater | [s]kip | [?] I don't know
  ```

  Direct advance canonically renders `[n]ext`, and `/next` remains its textual
  command. Literal `[n]o` is allowed only when an honestly binary question
  cannot be expressed more clearly with consequence-named verbs. `next` and
  `no` never compete on the same screen; if both seem applicable, `next` moves
  to the palette or the negative action receives an honest verb. Reuse is
  avoided when a natural alternative exists, but the grammar prefers an
  obvious initial over contrived forms such as `n[o]`. Inapplicable actions
  are omitted. `[s]kip` is always applicable and visible on an opportunity
  selected by the ordinary lottery; its variant defines the typed deferral,
  cooldown, and pressure without inventing a substantive outcome. Hard
  precedence and non-lottery screens expose only their truthful contextual
  routes. Shortcut allocation follows UX-254 rather than a global letter
  namespace.

- **UX-015 [core] — Suggested default.** `*` marks at most one defensible
  suggested action. On a finite choice with a visible default, pressing either
  literal `*` or Enter immediately selects that same action. The two keys are
  aliases for the displayed default, not separate semantic actions. Without a
  visible `*`, Enter does not guess and literal `*` is unbound. Input screens
  keep their editor grammar: `*` inserts text and Enter submits or advances as
  declared by UX-011. No evidence means no default unless the screen contract
  defines an explicit factory default, as UX-O02 does.
- **UX-016 [core] — Honest-answer assistance.** `[?] I don't know` is visible
  in every finite decision and always means `help me reach an honest answer`.
  It opens a bounded, deterministic assistance tree without recording an
  answer, skip, diagnostic response, cooldown, or random consumption. The tree
  asks one consequence-oriented question per screen, normally with
  `[y]es · [n]o · [?] I don't know`, and terminates in exactly one explicitly
  confirmed leaf. A classification leaf is an existing canonical choice; when
  the underlying answer requires missing information, judgment, authority, or
  consent, the leaf is instead one concrete recovery action or an honestly
  unresolved pending decision. Assistance never fabricates the original
  answer.
- **UX-017 [core] — Help remains a command.** Question mark keeps the UX-016
  meaning at every depth; it never changes into generic system help. Little
  Ant help is the contextual `/help` command reached through `[/] more...`.
  At a tree split, uncertainty shows one alternate consequence-oriented probe
  for the same distinction. Repeated uncertainty that still cannot choose a
  branch leaves the interaction pending. Escape and ordinary reverse
  navigation restore the preceding question exactly.
- **UX-018 [core] — Contextual later.** `[l]ater` exists only for honestly
  deferrable proposals and opens an explicit date choice before recording
  anything.

UX-252..259 close phase, shortcut, compact-layout, selection,
assistance-label, and no-emoji rendering.

## Navigation, undo, and commands

- **UX-019 [core] — Navigation is not mutation.** On an uncommitted choice
  screen with no active editable buffer or selection cursor, `Escape`,
  `Backspace`, and `Left Arrow` are equivalent: each restores the preceding
  checkpoint without a domain event. In text editing, `Backspace` deletes and
  `Left Arrow` moves the cursor; in a palette or another directional selector,
  arrow keys retain their declared selection behavior. `Escape` remains the
  universal cancel or return gesture. `Right Arrow` restores the next
  uncommitted checkpoint when one exists; choosing another branch discards
  that forward chain. After local backward navigation is exhausted,
  `Escape` and empty-buffer `Backspace` stop at the commit boundary. `Left
  Arrow` may instead preview the latest reversible recorded action and ask
  `Undo the last recorded action? [y]es · [n]o · [?] I don't know`; it does
  not compensate the action until `yes`. Symmetrically, after local forward
  navigation is exhausted, `Right Arrow` may preview the currently redoable
  action and ask `Redo the last undone action?` with the same grammar. With no
  eligible action, the arrow is a no-op with one concise educational hint.
  Thus arrows provide contextual discovery without making provisional
  navigation and semantic reversal the same core operation.
- **UX-020 [core] — Semantic undo.** `C-_` and `/undo` append a typed
  compensating event for the latest reversible action in the current
  interaction; they never delete history or consume a new draw. Confirming the
  boundary preview opened by `Left Arrow` invokes this exact operation. `no`,
  `Escape`, or `Backspace` closes the preview and restores the current screen
  without mutation.
- **UX-021 [core] — Semantic redo.** `C-M-_` and `/redo` reapply the compensated
  intent only if current preconditions still hold. Conflict is explicit.
  Confirming the boundary preview opened by `Right Arrow` invokes this exact
  operation. A newly committed action after undo invalidates any incompatible
  redo chain. External effects require a separately approved compensation.
  UX-197..199 define targeting, the exhaustive compensation classes, and
  conflict rules; UX-U02 is the contextual preview. No implementation may
  infer a generic inverse from an event name.
- **UX-022 [core] — More palette.** The canonical `[/] more...` action opens a
  searchable input palette containing only commands and secondary actions
  valid in the current state. Before any query, it shows a small,
  deterministically ordered contextual set. Typing filters the complete valid
  set; descriptions make any implicit current subject explicit. Arrow keys
  select, Enter runs, and Escape restores the exact pending interaction
  without an event or another draw. A read-only command returns to that
  interaction. A mutating command resolves it or revalidates it against the
  new revision. The palette guides required arguments. In ordinary input mode,
  `/` remains literal text. UX-S09 alone labels this unchanged palette `[/]
  menu...` because that screen also exposes local `[m]ore options...`; the
  shortcut, action identity, contents, and behavior do not change. This is not
  a global rename or permission for another screen to change the label without
  explicit review.
- **UX-023 [core] — Grammar inspection.** `lant grammar`,
  `lant grammar --screen <grammar>`, and `lant grammar --json` expose the same
  versioned registry used by all surfaces. The current envelope remains the
  authority for state-valid actions.
- **UX-024 [core] — Command transparency.** A confirmed guided action can show
  the exact canonical CLI command and canonical human result, teaching one
  scriptable language without exposing transport flags.
- **UX-278 [core] — The command registry is closed.** The
  [canonical command catalog](command-catalog.md) is the complete 1.0 public
  vocabulary. Every current envelope draws its valid commands from that
  registry; an implementation, Pack, assisted surface, or documentation
  example cannot add an alias or an unregistered action. A new public command
  requires an explicit specification revision, grammar entry, dumb route,
  typed errors, and conformance replay.
- **UX-279 [core] — Slash and CLI are one semantic language.** REPL slash
  commands and CLI forms map to the same dispatcher operation and preview.
  The catalog's few administrative namespaces organize staged operations; they
  do not create alternate meanings. Missing REPL arguments are guided, while
  missing noninteractive CLI arguments fail with exact usage. Neither surface
  guesses a target from recency.
- **UX-280 [core] — One list command exposes the two lists.** `/list` asks
  `importance order` or `focus forecast`, with no default. The first renders
  the strict sibling tree; the second renders current positive chances and
  their bounded explanations. Both are cursor-stable, scoped, read-only, and
  consume no draw. `/forecast` and `/importance` are not aliases.
- **UX-281 [standard] — Administration stays out of the lazy-human path.**
  Explicit `lant tick`, grammar inspection, diagnostics, and repair are
  CLI-only. Every ordinary command still performs the canonical tick, so the
  human never needs an administrative command to keep daily behavior correct.
- **UX-282 [standard] — Export is read-only and host-bounded.** `/export`
  guides exporter and scope selection. The CLI writes validated bytes to
  stdout or exclusively creates one named new regular file. It never
  overwrites, publishes, opens, or executes output, and Pack code receives no
  filesystem path or authority.
- **UX-283 [standard] — Profiles have a minimal lifecycle.** `/profile` and
  `lant profile list|show|create|use` are the entire 1.0 profile manager.
  Creation previews resolved typed paths and an empty or explicitly selected
  dataset. Selection follows DAT-059. Removal is deliberately absent because
  deleting a dataset and credentials is not required for daily use and would
  need a separate destructive-data contract.
- **UX-284 [core] — Unknown commands teach without acting.** An unknown or
  unavailable command shows its stable reason and up to three nearest valid
  canonical commands, preferring an exact semantic replacement when one is
  declared in the rejected-vocabulary table. It leaves the pending interaction
  and random cursor unchanged. Assisted interpretation may prevent the error,
  but its receipt still names the invoked canonical command.
- **UX-285 [core] — Raw duplicate review preserves both receipts.** UX-T10
  implements MOD-011, MOD-067, and FED-016 after Feed durability. Yes records
  the later Raw's `duplicate_of` link to the canonical root and its triage
  disposition; no records revision-scoped negative evidence and returns the
  Raw to ordinary triage; skip applies the review cooldown without settling
  either outcome. Question mark inspects both complete representations,
  provenance, revisions, and existing direct relationships before returning
  to the same question. An exact compatible digest may mark yes as the
  mechanical default. Assisted semantic evidence may mark and explain one
  visible proposal with attribution, but the human still accepts the same
  dumb action. Undo detaches only this link and restores the prior triage
  disposition; redo revalidates both revisions before restoring it.
- **UX-074 [core] — Compound slash-command grammar.** A public slash-command
  identifier is one lowercase kebab-case token. Whitespace ends the identifier
  and begins an argument or palette query; it never joins words in a command
  name. The core therefore exposes `/focus-blocker`, not `/focus blocker` or
  `/focus_blocker`, and provides no spelling aliases. Assisted surfaces may
  interpret natural language but render and invoke the canonical token.
- **UX-075 [core] — Unified person-or-company lookup.** A guided flow that
  needs an ExternalEntity target opens one `@` autocomplete containing
  eligible existing records and, when creation is valid in that context, the
  explicit human-facing candidate `New person or company...`. Ordinary screen
  copy uses contextual nouns such as person, company, team, or service rather
  than exposing the technical term `ExternalEntity`. The flow does not ask a
  preliminary `find or create` question. Typing filters both handle and
  declared name without mutation; Up/Down moves the selection, reverse video
  identifies it on capable terminals, and Enter chooses the displayed
  revisioned action. Selecting creation enters canonical typed creation and
  then returns its result to the suspended flow; the dumb host never guesses a
  kind from a name. Escape, Left Arrow, and empty-buffer Backspace follow
  UX-019. Proper names keep their declared spelling, so this input omits the
  ordinary suggestion to write prose in English.
- **UX-076 [core] — Typed handle autocomplete.** Typing `#` in a
  reference-capable input opens Brick autocomplete; typing `+` opens Raw
  autocomplete; and typing `@` opens person-or-company autocomplete. Search
  matches the canonical handle plus the Brick title, Raw original and current
  English-normalized content, source label or filename, or ExternalEntity
  name as applicable. Results always use the complete typed rendering from
  MOD-010. `New Brick...`, `New raw material...`, or `New person or
  company...` appears only when creation is a valid action in the suspended
  interaction. `New raw material...` suspends the field, enters the canonical
  Feed draft, and returns the accepted Raw reference; it is not a second Raw
  creation mechanism. Selecting a result returns its UUID-backed reference;
  the user never has to memorize or type an internal UUID. Merely typing or
  pasting a sigil does not turn lookalike literal text into a semantic
  reference: autocomplete selection or another explicit disambiguation is
  required.
- **UX-077 [standard] — Editable suggested text.** A guided text editor opened
  from an explicit `edit` action may be prefilled with an attributed factory,
  powered-up, or Skill suggestion. The whole suggestion starts selected using
  the surface's accessible selection treatment. Printable input or paste
  replaces the selection; Backspace or Delete removes it; and an arrow key
  collapses the selection and moves the cursor with conventional editor
  semantics without changing the text. Enter previews the current text rather
  than sending or otherwise applying it, and Escape restores the preceding
  preview without mutation. Once the human changes the text, the visible
  label changes from `Suggested message:` to `Message:`. Technical origin and
  revision attribution remain available through contextual assistance,
  history, and structured projections; identifiers such as template keys do
  not appear in the primary screen.
- **UX-078 [standard] — Repeatable completion context.** When a
  `repeatable_run` has a prior completed execution, its Work presentation
  exposes `Last completed: <absolute date>` in the secondary context region.
  This is historical orientation, not a deadline, recency judgment, forecast
  explanation, or new opportunity. It does not alter the shared `Work:` and
  `Focus?` primary grammar, and the primary question does not become `Read
  again?`, `Repeat?`, or another Nature-specific prompt. Accepting starts
  another execution of the same Brick identity; it does not create an
  occurrence Brick, reinsert importance, or replace the Brick.
- **UX-079 [standard] — Honest compact history.** Secondary context may expose
  a compact standing-work history only when every visible cell has a canonical
  period or occurrence under `WRK-064`. Habit history may pair a labeled
  streak with completed and unfulfilled windows. Repeatable Work may show a
  completion count beside `Last completed`, but never an invented missed
  cell. Recurring obligations show open and resolved occurrences rather than
  streaks. Habit history uses one oldest-to-newest token per applicable window:
  `[x]` for completed and `[-]` for unfulfilled, followed by a textual current-
  or next-window label. Blocked, paused, and inapplicable windows remain words
  and create no token. Without reliable glyph or display-width support, the
  strip becomes `done · unfulfilled` in the same order. Repeatable and
  recurring-obligation history uses the textual forms in UX-F08 and UX-RO00;
  neither borrows habit cells. Color is never the only distinction.
- **UX-080 [core] — Stale focus remains a continuation.** At the first safe
  interaction boundary on or after the configured stale-focus threshold, the
  current-focus continuation asks `Still working on this?` and exposes
  `[y]es · [s]kip · [?] I don't know · [d]one`, followed by `[/] more...`.
  It is not selected by `next`, does not consume randomness, and does not add
  a `focus_review` opportunity. `yes` records one explicit focus check-in,
  resets only the stale-focus clock, and returns to the sober current-focus
  screen without creating another WIP or focus interval. `skip` opens the
  ordinary served-work symptom screen without recording anything by itself;
  `done` performs the immediate reversible completion under `WRK-049`; and
  uncertainty changes nothing. `Last activity` is the latest explicit focus
  start, resume, or check-in timestamp. It is not measured work, effort, or
  proof of continuous activity.
- **UX-081 [core] — Non-current WIP review grammar.** A selected `wip_review`
  uses the `Review:` heading, identifies the WIP Brick, states `This Brick is
  still in progress.`, and asks `What should happen?`. Its visible actions are
  `[r]esume · [s]kip · [?] I don't know` followed by `[d]one · return to
  [i]dle`, then `[/] more...`. `Last focused` appears in the temporal footer
  block above the current clock. `resume`, `done`, and `idle` follow
  `WRK-065`; `skip` is the typed lottery-review deferral and never opens the
  served-work symptom screen. Uncertainty and Escape preserve the pending
  review. The screen has no decorative personality line.
- **UX-082 [core] — Nature does not multiply screen grammar.** A Nature changes
  presentation only when its valid actions or transition family genuinely
  differ. An undecomposed `project` and an `atomic_task` therefore share the
  ordinary `Work:` composition in UX-F01; no project-only preflight or
  empty-project screen intervenes. Decomposition may later change selection
  boundaries under `FOC-011`, and a completed child scope may create a typed
  review, but neither fact creates one screen per Nature. Capability-specific
  fragments compose into the smallest existing grammar under `FOC-009`.
- **UX-083 [core] — Scope-closure review grammar.** A selected
  `scope_closure_review` uses the `Review:` heading, identifies the finite
  parent, and asks `What should happen?`. The `child_parts` purpose states
  `All <count> tracked parts are done.` and uses `Last child done` as its
  primary temporal fact. The `list_entries` purpose states that no entry is
  open, reports resolved and cancelled counts separately, and uses `Last run`
  as its temporal fact. Both expose `[d]one · [a]dd more work`, followed by
  `[s]kip · [?] I don't know` and `[/] more...`, without a default. Actions
  follow WRK-066; uncertainty and Escape preserve the pending review. The
  screen has no Nature label, project-only wording, completion inference, or
  decorative personality line.
- **UX-084 [core] — Big-recovery grammar.** Selecting `bi[g]` on the served-work
  symptom screen opens a provisional reaction on the same Brick. It asks
  `What would help?` and exposes `[b]reak it into parts`, `[c]ollect more
  context`, `[l]earn about the subject`, `[s]kip anyway`, `[?] I don't know`,
  and `[/] more...`, in that order and without a default. Actions follow
  `WRK-067`. Escape, empty-buffer Backspace, or Left Arrow restores the exact
  symptom screen without evidence or mutation. The screen has no technical
  Nature explanation or decorative personality line.
- **UX-085 [core] — Dumb part collection.** Choosing `break` opens one pending
  editor headed `Break into parts:`. Entering from an existing-parts manager
  instead heads the same editor `Add parts:`. It identifies the retained Brick, lists
  every drafted part in entry order, and keeps the next numbered `›` input
  active. Enter on non-empty text adds that draft and immediately opens the
  next line. A first decomposition advances to UX-B01 only after two drafts;
  an additive route advances after one. Before its applicable minimum it
  cannot produce a preview. The input
  displays the discreet title-specific hint `Tip: write Brick titles in
  English.` under UX-049. Escape, Left Arrow, or Backspace on an already empty
  input restores the preceding pending-part checkpoint. No title, handle,
  Nature, comparison, child, symptom, or history is durable during collection.
- **UX-086 [standard] — Assisted decomposition draft.** When title,
  Raw attached as description, linked material, or related-Brick evidence
  supports a concrete decomposition, powered-up mode or the Skill may precede
  UX-085 with one English-language draft containing every suggested part and a
  concise attribution to the evidence used. The screen asks `Use this draft?`
  and exposes `[y]es`, `[e]dit`, `[n]o`, `[?] I don't know`, and
  `[/] more...`, without `*`. `yes` advances to the ordinary complete UX-B01
  preview; `edit` opens UX-085 seeded with the suggestion; `no` discards it
  and opens empty UX-085; uncertainty explains the evidence and returns.
  Weak or conflicting evidence bypasses the proposal and renders the exact
  dumb flow. Assistance never allocates durable identities, accepts
  human-comparison evidence, hides a proposed relationship, or mutates the
  log. Assisted Nature, initial order, and Dependency claims remain visibly
  attributed and lazily reviewable under MOD-052 and IMP-030. The canonical
  CLI validates every proposed value and remains the only mutation authority
  under UX-001.
- **UX-087 [standard] — Assisted inline part suggestion.** While UX-085 has an
  empty active line, an assisted surface may show at most one attributed
  suggested part. Tab accepts it into the editor without submitting it; any
  ordinary text input dismisses the suggestion and begins the user's own
  title. The suggestion changes no prior draft, skips no confirmation, and is
  absent when evidence is insufficient. Other surfaces expose the same
  `accept suggestion` action through their native control under UX-003.
- **UX-088 [core] — Human-facing break preview.** UX-B01 is the sole final
  confirmation for a part batch. It identifies the retained Brick, states
  naturally any resolved destination Nature (`project` in the reference first
  decomposition) and that active parts replace a finite parent as suggested
  Work, lists pending
  parts without not-yet-durable handles, and
  groups the deterministic `atomic_task` and entered-order lazy-review
  defaults. It asks `Apply this change?` and exposes `[y]es`, `[e]dit`, `[n]o`,
  `[?] I don't know`, and `[/] more...`, without a default. `yes` performs the
  one atomic mutation; `edit` restores UX-B00 with every draft; `no` discards
  the drafts, cancels decomposition, and restores its origin without evidence;
  uncertainty explains Nature, order, and provenance before returning.
  An additive variant names no Nature transition, preserves existing children,
  and uses the IMP-045 tail run. Reverse navigation follows UX-019 and
  preserves the drafts. An assisted
  preview adds only explicit exceptions to the dumb baseline and marks every
  proposed Nature, initial-order, or Dependency claim `AI-suggested · review
  later`. Accepting the whole preview does not erase that provenance. When
  entry came from `big`, `yes` also records that symptom and recovery; direct
  `/break` never fabricates them.
- **UX-089 [core] — Committed part result.** After UX-B01 `yes`, UX-B02 states
  `Broken into <count> parts:` for first decomposition or `Added <count>
  <part|parts> to:` for an additive direct/served-work origin, renders the retained parent and newly durable
  children with their allocated handles, explains that children may now
  appear as Work and that the parent returns only for scope review, and offers
  `[n]ext` followed by `[/] more...`. A Plan origin instead reaches the
  additive UX-S38 receipt under UX-175. Neither performs an automatic forecast draw,
  exposes no direct `focus first part`, and has no personality line. `next`
  invokes the ordinary weighted pipeline; the displayed sibling order never
  implies execution sequence. The footer uses `Changed` as its temporal fact
  and immediately counts every new active child plus unresolved lazy reviews
  under FOC-040. The palette exposes contextual `/undo` under UX-020 and
  structure inspection without competing with the primary advance.
- **UX-090 [core] — Nature-review grammar.** A selected `nature_review` uses
  `Review:`, identifies the Brick, shows `Current Nature:`, names the current
  Nature, and explains its source in natural language before asking `Is this
  the right Nature?`. It exposes `[y]es`, `[c]hange`, `[s]kip`, `[?] I don't
  know`, and `[/] more...`, in that order and without `*`. `yes` follows
  MOD-053 and reduces the unresolved-review count by one; `change` opens the
  canonical Nature choice for the existing Brick; `skip` is the typed review
  cooldown under FOC-040 and never opens served-work diagnosis. Uncertainty
  explains Nature consequences and source evidence before restoring the same
  opportunity. Reverse navigation preserves the pending review. Factory and
  assisted sources use human prose rather than internal source identifiers.
- **UX-091 [core] — Importance-review cadence.** A selected
  `importance_run_review` renders the ordinary proposition-led importance
  comparison without a `Review:` heading or `*`. `[m]ore important` and
  `[l]ess important` each record one answer, complete the current lottery
  interaction, and return the minimal UX-O04 result without drawing. If the
  run remains unresolved, the same marker stays counted and FOC-041 boosts
  subsequent `importance_maintenance` draws; explicit `[n]ext` still owns the next global
  draw. `skip` follows the bounded alternative-comparator behavior in IMP-031,
  while uncertainty and reverse navigation record nothing. Explicit `/order`
  uses the same screen and `org-sort-tasks` state but, after an accepted answer,
  immediately renders the next unresolved pair without an intermediate result
  or global draw. It never renders a per-answer success receipt in this direct
  cadence; only a real boundary in UX-093 produces a result. It stops when the
  chosen scope is coherent or the user exits.
- **UX-092 [core] — Explicit ordering scope.** Entering `/order` without an
  argument opens UX-O02 with only applicable scopes: current sibling group,
  current Domain, all unresolved groups, and explicit target selection. `All
  groups` is first and is the explicit factory default. `/order #ctpe`
  directly selects the direct children of that uniquely resolved parent; a
  selected Domain is rendered canonically as,
  for example, `/order "Personal › Housekeeping"`. Arguments are completed
  through the same revisioned palette contract as other guided references.
  Typing `#` filters parent-Brick handles and titles; unprefixed text searches
  both Brick titles and canonical Domain paths. A Brick match is displayed as
  the complete command and typed reference, such as `/order #bs "Bring
  something..."`; a Domain match displays its complete quoted path. Selecting
  either returns its UUID-backed or canonical Domain reference and Enter starts
  the direct IMP-031 cadence. The REPL never requires a memorized title,
  handle, or Domain path, never resolves an ambiguous partial query silently,
  and never offers target creation from this selector. Domain and all-groups
  scopes follow IMP-032 and cannot create cross-parent comparisons.
- **UX-093 [core] — Continuous-order exit.** While UX-O01 is running in
  explicit `/order` cadence, Escape or empty-input Backspace leaves the current
  unanswered pair untouched and renders UX-O03. Every previously accepted
  comparison remains durable. Left Arrow instead invokes the semantic-undo
  boundary in UX-020 for the latest accepted comparison; leaving and undoing
  are distinct intentions. An incomplete scope reports comparisons recorded
  and sibling groups still needing review, then offers `[r]esume`, `[n]ext`,
  and `[/] more...`. A coherent scope reports completion and offers `[n]ext`
  and the palette. `resume` continues the same checkpoint; `next` leaves
  explicit maintenance and invokes the ordinary global forecast. `Ordering
  paused` is result copy, not a Brick lifecycle state or persistent session
  mode.
- **UX-094 [standard] — Honest startup splash.** An interactive REPL cold
  start renders UX-R02 while authoritative JSONL events are being decoded
  and folded. It shows the factory ant mark, product wordmark, and one
  monotonically increasing, at-least-six-digit `Loading` counter for events
  actually processed. It never sleeps to make the animation visible, invents
  progress, consumes forecast randomness, emits a domain event, or delays an
  already-ready screen. Cursor updates rewrite the counter in place rather
  than scrolling. With a small dataset it may be imperceptible because it has
  no minimum duration; with no replay work it is omitted. Non-interactive,
  redirected, `TERM=dumb`, and
  motion-disabled output never receives cursor animation or splash bytes.
  Cancellation leaves canonical data unchanged; malformed input stops on the
  ordinary typed startup error instead of displaying false completion.
- **UX-095 [core] — Results belong to interaction boundaries.** A guided
  classification or comparison sequence does not render a success receipt
  after each accepted answer. The accepted answer either advances directly to
  the next step in the same cycle or, when it closes the cycle, produces one
  stable result. Binary insertion therefore acknowledges only final placement,
  Nature or Template discovery acknowledges only resolved classification, and
  explicit `/order` follows UX-093. A lottery-selected
  `importance_run_review` is intentionally a one-comparison cycle under
  IMP-031, so its single accepted relation renders the minimal UX-O04 result.
  That result acknowledges the interaction boundary, not a new forecast draw
  or a general rule that every `more` or `less` answer needs a receipt.
- **UX-096 [core] — Ordering-skip cadence.** The first `skip` on UX-O01 records
  no importance edge and immediately redraws the same proposition with the
  replay-deterministic nearby sibling from IMP-008. It has no receipt,
  personality copy, or explanatory heading; UX-O11's read-only context can
  explain the changed comparator. Skipping that replacement commits the
  low-confidence placement from IMP-009. In explicit `/order`, the next unresolved pair
  appears immediately and the final UX-O03 summary reports how many placements
  still need review. In lottery cadence, the second skip ends the cycle with
  UX-O05, applies review-specific cooldown, and performs no draw. Neither skip
  means equality, `less important`, nor permanent unimportance.
- **UX-097 [core] — Fresh contradiction gate.** When a newly answered
  direction would close a minimal cycle whose supporting edges all satisfy
  IMP-034 freshness and confidence, the answer remains pending and UX-O06
  interrupts the current cadence before another pair or result. The screen
  lists each conflicting direct judgment with absolute local time and complete
  Brick citations, then offers `[c]hanged`, `[m]istake`, and `[?] I don't know`
  without a default or lottery `skip`. `changed` atomically activates the new
  direction and retires every older edge in the displayed conflicting path
  from current calculation. `mistake` retracts the pending answer and records
  its direct reverse. Both preserve immutable evidence and resolution reason.
  Uncertainty opens UX-O07. Escape preserves the pending resolution and the
  prior coherent effective order; it never silently chooses by recency.
- **UX-098 [core] — Three-way contradiction aid.** UX-O07 asks which one of
  the three affected siblings should be chosen if only one could ever be done.
  This counterfactual measures importance, not urgency or present availability.
  It has no default, model answer, or hidden impact calculation. Selecting
  one records two direct current judgments placing that winner above each
  other Brick, retires only incompatible current edges, preserves an applicable
  coherent relation between the two non-winners, and resumes the interrupted
  cadence. The visible shortcuts are stable unique characters from the three
  displayed choices under UX-013. A second uncertainty response and minimal
  cycles longer than three follow UX-101 rather than expanding this screen.
- **UX-099 [core] — Provocative validation surface.** An FOC-042
  `importance_validation` renders the exact ordinary UX-O01 proposition and
  actions, with no `Review:`, `Validation:`, inferred direction, `*`, or other
  leading clue. Contextual `?` may reveal the applicable transitive path,
  effective confidence, and fact that the pair has no prior direct judgment;
  it never answers. A confirming direction uses the compact UX-O04 receipt. A
  contrary direction follows IMP-013 and UX-097 when the path is still fresh.
- **UX-100 [core] — Still-uncertain contradiction result.** A second
  uncertainty response on UX-O07 records the unresolved resolution described
  by IMP-035 and renders UX-O09 without drawing. The result says that the
  previous order remains in use and counts placements needing review; it does
  not repeat the cycle, choose a winner, claim equality, or expose a numeric
  score. `[n]ext` returns to the global forecast. When reached inside explicit
  `/order`, the same semantic outcome advances directly to an unaffected
  segment when one exists; UX-O09 appears only when that direct cycle reaches
  its next real result boundary. Repeated consequential uncertainty may later
  propose IMP-016 investigation work through an explicit confirmation.
- **UX-101 [core] — Iterative longer-cycle aid.** A minimal cycle longer than
  three renders UX-O07 repeatedly over the deterministic triads in IMP-036;
  it never lists the whole cycle as one giant finite choice and introduces no
  new grammar. After each winner the core recomputes the cycle before deciding
  whether another triad is necessary. If none remains, the interrupted cadence
  resumes or reaches its ordinary result boundary. Contextual help may show the
  complete cycle and current triad, while the primary screen remains bounded.
  Uncertainty at any triad follows UX-100 and ends the aid.
- **UX-102 [core] — Provocative-validation skip.** On the first `skip` of an
  FOC-042 `importance_validation`, the core immediately renders one other
  eligible validation pair from the same sibling group when available, using
  the unchanged UX-O01 grammar and no interstitial. A second skip, or the first
  when no alternative exists, records only IMP-037 cooldown and renders UX-O10
  without drawing. The result states that the current order remains in place.
  It never says `positioned`, lowers confidence, creates a provisional
  placement, or increments unresolved reviews. Contextual help continues to
  distinguish validation from unresolved sorting.
- **UX-103 [core] — Tired reaction grammar.** Selecting `tired` from the
  served-work symptom screen opens UX-S07 with `easier work`, `change
  subject`, `pause for now`, `skip anyway`, and uncertainty. The screen is a
  reaction choice, so it has no personality line and records nothing until a
  final reaction is accepted. Reverse navigation restores UX-S01 exactly.
- **UX-104 [core] — Easier-work shortlist.** Choosing `easier work` opens
  UX-S08 with up to three fully cited executable candidates and asks which
  feels easiest to tackle now. Visible `[1]`, `[2]`, and `[3]` bindings select
  by stable screen position; finite choice does not need to manufacture a
  mnemonic from arbitrary titles. There is no `*`, hidden ranking, or effort
  value. `[?] I don't know` explains the bounded comparison without choosing;
  reverse navigation restores UX-S07 without mutation. Selecting a candidate
  follows WRK-069 and then renders the normal `Work:`/`Focus?` proposal for
  that candidate. Differing effective Domains are shown beneath only the
  affected candidate so that a quiet screen never hides a context switch.
  With zero candidates, UX-S08E follows UX-212; it never renders an empty
  selector, fabricates a candidate, or commits `tired` merely by appearing.
- **UX-105 [core] — Positive full-path subject choice.** Choosing `change
  subject` from UX-S07 or UX-S11 opens UX-S09 and asks what the user would
  rather work on. It first exposes `[o]rganize and review` only when an
  FOC-046 opportunity is eligible, then shows up to four
  replay-deterministically sampled target Domains with currently executable
  Work. Every Domain row spells its complete path with `›`; isolated leaf
  labels are forbidden. There is no dumb default. `[m]ore options...` pages
  through the remaining Domain pool without repeats, rejection evidence,
  mutation, or a draw; reverse navigation restores the previous page. The
  action disappears on the final page. `[s]kip anyway` records only the
  originating symptom under WRK-070. Because this screen has a local `more`
  action, the unchanged UX-022 palette is labeled `[/] menu...` here only.
  Powered-up or Skill may mark one attributed suggestion with `*`; rejecting
  it returns to this exact dumb baseline. Selecting a Domain follows WRK-070;
  selecting organization follows WRK-075. UX-208 and FOC-060 own
  multi-membership, no-Domain, and no-target cases.
- **UX-106 [core] — Tired-pause result rests.** Accepting `pause for now`
  follows WRK-071 and renders UX-S10 with `Taking a break:`, the complete
  served Brick citation, one truthful state sentence, optional replay-stable
  UX-064 `safe_end` microcopy, and only `[/] more...`. It exposes no primary
  `next`, `resume`, or focus action, performs no draw, and does not close the
  REPL automatically. The contextual palette remains available with only
  currently valid commands; this does not elevate them into the primary
  result. A non-terminal surface preserves the same resting envelope
  without pretending that an application process ended.
- **UX-107 [core] — Bored reaction grammar.** Selecting `bored` on UX-S01
  opens UX-S11 with `change subject`, `make it more interesting`, explicit
  `skip anyway`, and uncertainty, without a default or personality line.
  Subject change reuses UX-S09 with pending `bored` evidence; transformation
  opens UX-S12. No mutation occurs until a final reaction is accepted.
- **UX-108 [core] — Make-interesting grammar.** UX-S12 asks how the work could
  become more interesting and offers `try a short sprint`, `break it into
  visible steps`, `find a better way`, and uncertainty, without a default.
  Break reuses the complete existing UX-B00..B02 route. Find opens UX-S13.
  Short sprint opens UX-S15 and follows WRK-076..080; no surface may bypass
  its explicit duration or reinterpret elapsed time as observed work.
- **UX-109 [core] — Dumb better-way classification.** UX-S13 asks how the
  approach might improve and offers `automate repetitive parts`, `simplify the
  process`, `learn another method`, `get help from someone`, and uncertainty.
  No free text or model is required to reach a choice. Each action creates the
  corresponding editable FED-032 draft and opens UX-S14. `?` may ask the same
  distinctions as bounded mechanical questions but cannot select one.
- **UX-110 [core] — Better-way enabling preview.** UX-S14 shows the unallocated
  proposed title without a handle, the complete served Brick citation, the
  human relation `Do this first`/`Then return to`, and its visible lazy
  `atomic task` Nature claim. Actions are `[y]es`, `[e]dit`, `[n]o`,
  uncertainty, and the ordinary slash palette, without a default. `yes`
  follows WRK-074; `edit` may change title, Nature, placement, and whether the
  work is prerequisite or independent, then returns to the complete preview;
  `no` restores UX-S12 without mutation. Dumb free-text editing shows UX-049's
  English reminder. Assisted proposals remain visibly attributed.
- **UX-111 [core] — Organization is distinct from Domain pagination.** On
  UX-S09, `[o]rganize and review` appears in a separate block above `Or choose
  a subject:` and never participates in numbered Domain pages. Selecting it
  follows WRK-075 and FOC-046. If no organization-maintenance opportunity is
  eligible, the option is omitted rather than shown disabled. Contextual help
  names the included typed meta-work families; it never calls organization a
  Domain, Brick, importance value, or persistent mode.
- **UX-112 [core] — Sprint duration is a visible decision.** UX-S15 repeats
  the complete served Brick citation and asks `How long would you like to give
  it?`. It shows the factory 5-, 15-, and 25-minute choices, describes them as
  `just get started`, `a short attempt`, and `a Pomodoro`, and marks 25 minutes
  with `*` in dumb mode. A row number chooses that row; `*` or Enter chooses
  the visible default. `[c]ustom...`, uncertainty, reverse navigation, and the
  ordinary slash palette remain available. Custom uses bounded UX-S15A;
  a surface may not replace it with an unbounded guessed duration. Accepting a
  duration follows WRK-078 directly, without another Focus question or
  celebratory claim that work happened.
- **UX-113 [core] — An active sprint is visible but subordinate.** UX-S16 uses
  the sober `Current focus:` composition with ordinary `[d]one`, `[s]kip`, and
  `[/] more...`. Its temporal footer shows `Sprint: MM:SS remaining` plus the
  absolute local end instant, followed by the ordinary `Now` line. On a
  capable interactive terminal, the renderer may refresh only those temporal
  footer cells as the canonical clock advances; the remaining time is always
  recomputed from the target instant and never decremented as state. On a
  terminal that cannot safely redraw, after process restart, and in static
  web, text, redirected, or structured output, the same state shows the
  absolute `Sprint ends` fact without ANSI animation. Color and refresh never
  carry meaning.

  Expiration cannot overwrite typed input, an open palette, or another
  uncommitted interaction. At the next safe boundary the surface revalidates
  the same focused Brick and timebox. If an already committed action closed
  it, no stale expiry appears; otherwise canonical tick records elapsed and
  renders UX-S17 with the draft or palette checkpoint still recoverable.
- **UX-114 [core] — Sprint expiration asks what follows.** UX-S17 says `Sprint
  time is up:`, cites the complete focused Brick, and asks `What would you like
  to do?`. Its actions are `[c]ontinue`, `[a]nother sprint`, `[d]one`,
  `[p]ause`, uncertainty, and the ordinary slash palette, with no default and
  no personality line. Continue returns to sober current focus without a
  timer; another sprint opens UX-S15 with the prior duration selected; done
  and pause follow WRK-049 and WRK-048. Uncertainty explains these outcomes
  without changing state. The screen never calls elapsed time completion,
  effort, progress, or failure.
- **UX-115 [core] — Fear offers concrete recovery classes.** Selecting `fear`
  opens UX-S18 with `validate the risk first`, `make a safer first move`, `get
  support`, `skip anyway`, and uncertainty. The screen has no default,
  personality line, risk scale, or explanation request. Validate opens UX-S19;
  safer move opens UX-S20; support opens UX-S22; skip follows WRK-081.
  Uncertainty distinguishes evidence-gathering, reducing the first action's
  exposure, and involving another person without choosing among them.
- **UX-116 [core] — Dumb fear content is one short input.** UX-S19 asks `What
  should be learned or tested first?`; UX-S20 asks `What would be a safer first
  move?`. Both use the ordinary line editor, the quiet English reminder, and
  `[/] more...`. Submitting nonblank text opens UX-S21; Backspace edits before
  navigating, and only Backspace on an empty input, Escape, or Left Arrow
  restores UX-S18. No autogenerated placeholder is silently accepted.
- **UX-117 [core] — Fear enabling work uses the shared preview.** UX-S21 shows
  `Do this first`, the unallocated proposed title, `Then return to`, the
  complete served Brick citation, and the visible behavior claim. Validation
  shows `atomic task · validation · review later`; a safer move shows `atomic
  task · review later`. The actions are `[y]es`, `[e]dit`, `[n]o`, uncertainty,
  and the slash palette with no default. Yes follows WRK-082; edit returns
  through the applicable input and complete preview; no restores UX-S18.
- **UX-118 [core] — Support selection remains human and typed.** UX-S22 asks
  `Who could help?` with typed `@` autocomplete and `New person or company...`;
  raw arbitrary text is not silently treated as an ExternalEntity. After one
  selection, UX-S23 asks how that cited Entity could help and offers `[a]sk
  for advice`, `[w]ork together`, `[d]elegate this Brick`, and uncertainty,
  without a default. The routes follow WRK-083. Reverse navigation restores
  the prior checkpoint without mutation. Assisted suggestions remain visibly
  attributed and rejection returns to the identical dumb route.
- **UX-119 [core] — Vague asks what kind of clarity is missing.** Selecting
  `vague` opens UX-S24 and offers `[g]oal`, `[i]nformation`, `[f]irst step`,
  `[s]kip anyway`, and uncertainty. Each of the first three rows includes one
  short explanation, and there is no default, personality line, free-form
  diagnosis, or new semantic axis. Goal opens UX-S25; information enters the
  contextual collect-more-context route; first step opens UX-S27; skip follows
  WRK-084. Uncertainty explains the content-versus-work distinction and
  returns without choosing.
- **UX-120 [core] — Goal clarification previews a Description change.** UX-S25
  asks `What result should this Brick produce?` through the ordinary line
  editor and English reminder. Nonblank submission opens UX-S26, which cites
  the Brick, shows the complete proposed Description clarification, and asks
  whether to apply it. Actions are `[y]es`, `[e]dit`, `[n]o`, uncertainty, and
  the slash palette with no default. Yes follows WRK-085; edit returns to the
  selected text editor; no restores UX-S24. The primary screen never exposes
  unresolved Raw storage mechanics or calls the content a Definition.
- **UX-121 [core] — First-step recovery composes existing routes.** UX-S27 asks
  `How should we find a first step?` and offers `[b]reak it into parts`,
  `[l]earn about the subject`, `[g]et help`, `[s]kip anyway`, and uncertainty,
  without a default. Break reuses UX-B00..B02, learn enters contextual enabling
  Feed, and help reuses UX-S22..S23 while carrying provisional `vague` evidence.
  Reverse navigation restores UX-S24. No route records a symptom until its
  final existing preview or explicit skip is accepted under WRK-086.
- **UX-122 [core] — Hard exposes overlapping recoveries deliberately.**
  Selecting `hard` opens UX-S28 and offers `[l]earn or practice first`,
  `[b]reak into smaller parts`, `[f]ind an easier approach`, `[g]et help`,
  `[s]kip anyway`, and uncertainty, in that order and without a default or
  personality line. Break goes directly to UX-B00..B02 with `hard` carried;
  easier approach opens UX-S13; support opens UX-S22; and skip follows
  WRK-087. Uncertainty explains that difficulty, size, ambiguity, and fear may
  share a remedy without becoming the same symptom.
- **UX-123 [core] — Dumb learning recovery asks for a title.** Choosing `learn
  or practice first` opens UX-S29, whose line editor asks `What should be
  learned or practiced first?`, shows the quiet English reminder, and retains
  the ordinary slash palette. Nonblank submission enters contextual Feed and
  its complete Nature and enabling-structure preview under FED-040. Empty
  Backspace, Escape, or Left Arrow restores UX-S28. Assistance follows
  FED-041 and cannot bypass the same preview.
- **UX-124 [core] — Less-important recovery makes the affected axis explicit.**
  Selecting `less important` opens UX-S30 and asks `What should change?`. It
  offers `[o]rder it lower`, `[l]ater`, `[c]hange subject`, `[s]kip anyway`,
  and uncertainty, without a default or personality line. Uncertainty explains
  durable sibling importance, temporary eligibility, and one scoped Domain
  choice without selecting one. Reverse navigation restores UX-S01 exactly.
- **UX-125 [core] — Lower order enters canonical comparison grammar.** Order
  opens the ordinary UX-O01 `Is ... more important than ... ?` screen for
  IMP-039's first lower-sibling comparator. There is no `move down`, position,
  rank, yes/no, or confirmation shortcut. Escape before the first comparison
  restores UX-S30 without mutation; after an answer, semantic undo rather than
  screen navigation reverses committed evidence. A no-comparator result states
  that no lower sibling can be compared and returns without claiming a move.
- **UX-126 [core] — Time and subject reuse their existing selectors.** Later
  opens the ordinary guided absolute-date chooser and shows the resulting
  instant before acceptance through UX-DT00..DT02. Change subject reuses
  UX-S09's positive full-path Domain pages with provisional
  `less_important`, including its screen-local `[/] menu...` label. That
  variant omits `organize and review`, because this reaction asks for a
  subject rather than a work family, and follows FOC-047 instead of inferring
  tiredness or boredom.
- **UX-127 [core] — Other begins with one verbatim explanation.** Selecting
  `other` opens UX-S31, which asks `What else is getting in the way?` through
  the ordinary line editor, shows the quiet English reminder, and retains the
  slash palette. Nonblank submission opens UX-S32. Empty Backspace, Escape, or
  Left Arrow restores UX-S01. The entered text is not normalized into another
  symptom or promoted to Raw.
- **UX-128 [core] — Other requires explicit skip confirmation.** UX-S32 says
  `Skip this Brick for now because:`, quotes the complete entered text, and
  offers `[y]es`, `[e]dit`, `[n]o`, uncertainty, and the slash palette without
  a default. Yes follows WRK-093; edit returns to UX-S31 with the text selected;
  no restores UX-S01; uncertainty explains that the reason will remain
  unclassified verbatim evidence. After acceptance, the ordinary replay-stable
  skip result is rendered.
- **UX-129 [standard] — Assisted categorization stays provisional.** Before
  UX-S32 acceptance, powered-up or Skill may suggest one existing symptom with
  concise attribution. Accepting that suggestion discards no text, records
  nothing, and opens the existing symptom's reaction with the explanation
  preserved in the interaction checkpoint; rejecting it renders unchanged
  UX-S32. Assistance cannot create a symptom, commit a skip, or bypass the
  later taxonomy-review opportunity under WRK-094.
- **UX-152 [core] — Out-of-date recovery names the semantic outcomes.**
  Selecting `out of date` opens UX-S35 and offers `[a]rchive it`, `[r]eplaced
  by newer Work`, `[u]pdate it`, `[s]kip anyway`, and uncertainty, in that
  order and without a default. Archive follows WRK-099. Replacement opens an
  explicit supersession target and preview; update enters read-only inspection
  followed by canonical editing of the same Brick; neither records the
  symptom before its final accepted mutation. Skip records only the symptom
  and ordinary cooldown. Reverse navigation restores UX-S01 unchanged.
- **UX-153 [core] — Archive relevance review is a bounded lazy screen.** When
  FOC-053 selects the marker, UX-S36 identifies the archived Brick, archive
  reason, and archive instant, then offers `[k]eep archived`, `[r]estore it`,
  `[u]pdate and restore`, `[n]ewer Work replaced it`, `[s]kip`, and
  uncertainty, without a default. The first four actions preview their exact
  forward mutation before commit; review skip follows WRK-100. Immediate
  `/undo` of the original archive remains a distinct semantic compensation,
  not another label for restore.
- **UX-154 [core] — Update hub exposes semantic purposes.** UX-S37 asks `What
  do you want to update?` and lists `[m]eaning`, `[b]ehavior`, `[p]lan`,
  `[t]iming`,
  `[c]ontext`, `[s]ource material`, `[v]iew everything`, and uncertainty, in
  that order and without a dumb default. Each item includes one short human
  explanation and follows WRK-101; UX-UP01 and UX-UP02 are the canonical
  context and source-material submenus. View is read-only and restores the exact
  hub. Escape and reverse navigation restore the exact originating screen:
  UX-S35, UX-S36 including its pending review, or the interaction suspended by
  direct `/update`, without recording `out_of_date`.
- **UX-155 [core] — Update assistance and receipts preserve one grammar.**
  Powered-up or Skill may mark at most one existing hub purpose and give one
  concise attributed reason under UX-059; it cannot bypass the hub with a
  generic patch. Once the human enters a typed branch, assistance may propose
  one exact edit only through that branch's ordinary complete preview. Every
  accepted change renders UX-S38 with `[u]pdate something else`, `[r]eturn to
  Work`, and the slash palette. Update loops to UX-S37. Return restores a
  revalidated pending Focus screen, the current-focus screen, or—after archive
  restoration—ordinary Focus consent for the restored Brick; it never starts
  focus or draws another subject. The palette exposes semantic undo, and Left
  Arrow at the committed receipt uses UX-U01 rather than provisional back.
- **UX-156 [core] — Meaning choice stays two-way.** UX-S39 identifies the
  Brick and asks `What part of its meaning is stale?`, offering `[t]itle`,
  `[d]escription`, and uncertainty without a default. The explanations call
  title the short canonical name and description the longer context and
  intended result. Description is UI language for MOD-056's attached Raw, not
  a separate field. Escape and reverse navigation restore UX-S37 unchanged.
- **UX-157 [core] — Title uses selected prefill and stable-reference preview.**
  UX-S40 uses the ordinary single-line editor with the current title entirely
  selected, shows the quiet English reminder, and labels Enter as review rather
  than commit. Enter on changed nonblank text opens UX-S41; unchanged input
  returns one educational no-op and keeps the editor. The preview shows From,
  To, and the unchanged `#handle`, then offers `[y]es`, `[e]dit`, `[n]o`, and
  uncertainty without a default. Yes follows WRK-104 and renders UX-S38; edit
  returns with the draft selected; no discards it and restores UX-S39; Escape
  follows ordinary checkpoint navigation.
- **UX-158 [core] — Description preview exposes Raw consequences, not storage
  jargon.** Reviewing UX-S43 opens UX-S42 with complete current and proposed
  original text. When applicable it also
  states that the English normalization will need review and lists every other
  human-visible link or membership that will observe the same Raw revision.
  It never renders a Description entity, technical Raw ID, or false local-only
  edit. Actions are `[y]es`, `[e]dit`, `[n]o`, and uncertainty without a
  default. Yes follows WRK-105 and renders UX-S38; edit restores the multiline
  draft in UX-S43; no discards it and restores UX-S39.
- **UX-159 [core] — Multiline editing has one portable finish gesture.**
  UX-S43 opens with the complete current original description selected; an
  absent description opens an empty buffer. Printable input or paste replaces
  the selection, while arrows collapse it and use conventional text-cursor
  behavior. Enter inserts a newline. `Ctrl-D` reviews the complete buffer
  through UX-S42 or UX-S45 and never commits directly. Bracketed or ordinary
  multiline paste is one draft edit: embedded or trailing newlines cannot
  trigger review. Slash is literal text while the buffer owns input; `Ctrl-F`
  may suspend and restore the exact editor through global search. The quiet
  English-writing reminder remains advisory. No editor action creates a Raw,
  Raw revision, link, symptom, or domain event before an accepted preview.
- **UX-160 [core] — Leaving a changed multiline buffer protects the draft.**
  Escape with an unchanged buffer restores UX-S39 immediately. Escape or
  empty-buffer Backspace after a change opens UX-S44 with `keep the draft`,
  `discard it`, `continue editing`, and uncertainty. Keep is the visible
  default and restores UX-S39 while retaining only a resumable interaction
  checkpoint; selecting description again resumes it. Discard restores
  UX-S39 without the draft. Continue returns to the exact buffer, cursor, and
  selection. None records a domain event. After interruption or crash, a
  capable surface restores the exact checkpoint under UX-030 and states
  `Draft restored after interruption.` Non-terminal controls and Skill actions
  express these same intents without pretending to send terminal keypresses.
- **UX-161 [core] — Empty description review is explicit.** `Ctrl-D` on an
  empty new-description buffer is an educational no-op that keeps UX-S43.
  `Ctrl-D` after clearing an existing description opens UX-S45. That preview
  states that the attachment will be removed while its ordinary Raw, history,
  and other links remain. Yes follows WRK-105 and reaches UX-S38; edit restores
  the empty UX-S43 draft; no discards the draft and restores UX-S39. Empty
  input never silently creates an empty Raw, detaches a link, deletes content,
  or serves as a navigation alias.
- **UX-162 [standard] — External editing transports only a text draft.** In
  any compatible textual-Raw draft editor, the terminal chord `Ctrl-X Ctrl-E`
  asks its surface host to open the current complete buffer in the configured
  external editor. The host checkpoints the original draft, leaves raw or
  alternate-screen mode cleanly, writes only the original text bytes to a
  permission-`0600` secure temporary file, invokes the editor without a shell,
  and waits for it to exit. Resolution order is explicit Little Ant editor
  argv, then `$VISUAL`, then `$EDITOR`; environment fallback is tokenized into
  argv without command expansion, redirection, or pipelines. A GUI command is
  responsible for its own wait flag. Exit zero with changed nonempty content
  imports one new pending buffer and opens the ordinary preview; changed empty
  content opens the ordinary removal preview; unchanged content restores the
  internal editor with one discreet no-change hint. Spawn, read, or nonzero
  exit failure restores the exact prelaunch draft with one typed educational
  diagnostic. The host removes the temporary file after import or failure;
  after a crash it removes only stale temporary files it owns and never imports
  them. Recovery remains the interaction checkpoint, never that file. This is
  a host-mediated presentation capability under DAT-046, not Pack process
  authority, a domain effect, a special Raw revision route, or a facility that
  Skill and non-terminal surfaces must imitate.
- **UX-163 [core] — Behavior choice visibly means Nature.** UX-S46 labels the
  current Nature and explains its observable consequence before asking `How
  should this behave now?`. It reuses the example-backed canonical Nature
  list, marks the current row only with `current`, and assigns no `*` in dumb
  mode. Choosing the current row follows WRK-106. Question mark enters the
  mechanical Nature tree and result confirmation; Escape restores UX-S37.
  Powered-up or Skill may mark at most one different Nature with an attributed
  reason, but rejection restores this exact dumb grammar.
- **UX-164 [core] — Reclassification preview separates preservation from
  consequences.** UX-S47 renders the same Brick once, then `From`, `To`,
  `Preserved`, `Will change`, target configuration, and any explicit
  reconciliation before `[y]es`, `[e]dit`, `[n]o`, and uncertainty. It exposes
  no generic field names, Template selector, or storage diff. Yes and no follow
  WRK-107. Edit returns to the nearest typed configuration or reconciliation
  checkpoint and cannot mutate a preview field directly. If target-required
  or incompatible active state remains unresolved, the screen has no yes
  action and names the next typed decision instead. Assistance may propose
  values through those same builders, with provenance retained in the final
  preview; it cannot waive a conflict or approve itself.
- **UX-165 [core] — `/update` is the one direct semantic-maintenance route.**
  The canonical explicit command is `/update #brick`. When the current
  InteractionEnvelope identifies exactly one Brick, the contextual palette
  may show a resolved action such as `/update #rrsr "Review Rock Splitter
  rules"`; selecting it enters UX-S37 without another target question. In all
  other contexts, `#` autocomplete resolves the required Brick before the hub
  opens. Direct entry uses the neutral `What do you want to update?`, follows
  WRK-108, and returns to the exact suspended interaction after an event-free
  exit or completed update. The grammar registry exposes no `/edit` or
  `/plan` alias.
- **UX-166 [core] — Plan choice remains small and human-facing.** UX-S48 asks
  `What do you want to change?` and offers `[s]tructure`, `[b]lockers`,
  `[r]esponsibility`, and uncertainty, in that order and without a dumb
  default. Each row gives one concrete explanation; it does not expose
  composition, gate, relationship, or Delegation type names as the primary
  choice. Assistance may mark at most one existing row with an attributed
  reason under UX-059. Escape restores UX-S37 without evidence.
- **UX-167 [core] — Plan blocker classification omits skip-only grammar.**
  Selecting blockers opens UX-S49 with the same subject, question, five
  situation choices, and shortcut letters as UX-S02. It deliberately omits
  the `Continue without identifying it?` section and `[s]kip anyway`, because
  no served-work skip is pending. Every selected situation enters the same
  typed builder and preview used from UX-S02 but follows WRK-110 at commit.
  Escape and reverse navigation restore UX-S48. Powered-up and Skill may mark
  one existing situation and explain it, but may neither restore the absent
  skip action nor bypass the typed preview.
- **UX-168 [core] — Structure presents the same three intents for every
  Nature.** UX-S50 asks `What do you want to organize?` and lists `[w]ithin
  larger Work`, `[p]arts`, `list [i]tems`, and uncertainty, in that order and
  without a dumb default. All three remain visible and selectable even when
  the current Nature cannot represent the requested result. The explanations
  distinguish parent placement, independently tracked child Bricks, and
  entries shown together without leading with ontology names. Escape restores
  UX-S48 without evidence.
- **UX-169 [core] — Structural incompatibility is an attributed proposal, not
  a hidden conversion.** After an incompatible intent is selected, the screen
  explains the current mechanical limitation and enters the smallest
  applicable Nature distinction and WRK-112 preview. It never disables the
  selected row, silently changes Nature, or drops existing state. Powered-up
  and Skill may mark one of the same structure intents or propose a fully
  resolved compatible result through UX-060, but rejection returns to exact
  dumb UX-S50. The parent mover, child manager, parts compatibility, and
  incompatible-parent screens are settled by UX-170..179; the ListEntry route
  is settled by UX-180..181, and responsibility by UX-182..183.
- **UX-170 [core] — Move preview compares Domains mechanically.** When the
  selected parent and moving Brick have unequal direct Domain path sets, the
  move preview uses UX-S51. It renders From, To, the complete current and new
  parent Domain paths, and one structural conclusion: paths are related by
  ancestry, partially overlap, do not overlap, or one side has no Domain.
  Actions are `[y]es, keep current Domains`, `[c]hange Domains...`, `[n]o`, and
  uncertainty, without a dumb default. Yes follows WRK-113; change enters the
  typed Domain editor and returns to a combined preview; no restores the parent
  selector. Assistance may mark change and append one attributed semantic
  reason, but the dumb renderer never claims semantic distance. Parent
  selection follows UX-171; equal-Domain and literal-root moves follow the
  compact UX-172 preview.
  Literal `<root>` is not a parent Brick and supplies no membership set to
  compare: moving to root therefore uses the compact preview and preserves the
  moving Brick's direct Domains rather than fabricating a missing-parent
  contrast.
- **UX-171 [core] — Parent autocomplete keeps root, existing, and new scope in
  one place.** UX-S52 identifies the moving Brick and current parent, then
  opens `New parent ›` as a searchable input without a default. Typing `#` or
  title text filters eligible Bricks by canonical handle and title. Results
  use complete `#handle "title"` rendering and may also contain literal
  `<root>` and `New larger Work...`; the current parent is labeled `current`
  when matched. Self and descendants never appear. Selecting root or another
  parent continues to the appropriate compact or UX-S51 preview. Selecting
  new Work opens only an uncommitted draft and later returns to one combined
  preview under WRK-114. Escape, Left Arrow, or empty-buffer Backspace restores
  UX-S50 unchanged. Powered-up and Skill may reorder the same eligible set and
  mark one result with an attributed reason; rejection restores the dumb
  ordering and query. UX-203 defines exact dumb ranking ties.
- **UX-172 [core] — Same-context moves use one compact confirmation.** UX-S53
  follows UX-S52 when the eligible existing parent's direct Domain path set is
  canonically equal to the moving Brick's set, or whenever the selected target
  is literal root. It renders the moving Brick, complete old and new parents,
  one quiet `Domains stay the same.` line only when the Brick has a direct
  Domain, and `An importance comparison comes next.` only when IMP-004 has a
  genuinely unresolved first comparator. It omits the UX-S51 contrast,
  relationship conclusion, and `change Domains` action. Actions are `[y]es`,
  `[n]o`, uncertainty, and the slash palette, without a default or personality
  line. No and reverse navigation restore UX-S52 with its query and selection
  intact. Yes first revalidates subject and target under UX-029..031, then
  applies WRK-113, MOD-031..032, and IMP-004 as one reparenting boundary: the
  composition placement and deterministic low-confidence sibling position
  change together; internal subtree order and every unrelated fact remain;
  old-scope comparisons become inactive history; and any affected scope review
  is only the existing derived consequence. No forecast draw occurs. Existing
  resumable insertion continues immediately only while an unresolved
  comparator exists; accepted answers use the ordinary comparison grammar and
  UX-095 cadence, and exit always leaves a valid provisional position. An
  empty or already-resolved sibling set goes directly to the existing UX-S38
  receipt. At resolution or exit, that receipt varies only its fact block to
  show old and new parent; the footer already carries unresolved-review counts.
  Update-something-else reaches `context` in one further hub choice, while
  return-to-Work neither focuses nor draws. Selecting the current parent—or
  selecting root while already at root—remains UX-S52's event-free no-op and
  never reaches this preview. Powered-up and Skill may annotate or rank the
  selector but cannot skip UX-S53, add a default, or accept the move.
- **UX-173 [core] — Move uncertainty asks one human grouping question.** From
  UX-S53, question mark opens UX-S54 and asks whether the user would expect to
  find the Brick within the proposed larger Work when organizing it; the root
  variant asks whether it belongs at top level. Yes returns to unchanged
  UX-S53, whose `[y]es` remains the sole commit action. No returns directly to
  UX-S52 without a second confirmation. Question mark reveals one read-only
  consequence summary: the parent and new-sibling importance position may
  change and old/new scope may later need review, while identity, handle,
  meaning, Domains, blockers, waits, delegations, focus/WIP, and the internal
  subtree remain.
  It then asks the same grouping question once more. A second uncertainty
  response returns unresolved to UX-S52; it records no judgment, movement,
  comparison, review, or random-state change. Escape, Left Arrow, and
  empty-buffer Backspace restore UX-S53 unchanged from either question.
  Read-only `/show` may inspect both records and return to the exact question,
  but never substitutes for the consequence summary.
- **UX-174 [core] — Existing parts use one bounded factual screen.** UX-S55
  appears only when the selected Brick already has direct child Bricks. It
  identifies the parent, shows active children first in current importance
  order, and then a bounded inactive summary whose visible rows carry their
  plain `done`, `archived`, `superseded`, `merged`, `missed`, or `cancelled`
  state without claiming a
  current importance slot or aggregate completion. Overflow is stated by
  count, and the contextual `/show #parent` projection returns to the
  unchanged screen.
  Primary actions are `[a]dd parts`, `[o]rder active parts` when at least two
  active children exist, uncertainty, and the slash palette, with no default.
  Add reuses UX-B00; order reuses the ordinary continuous `/order #parent`
  cadence. Its UX-O03 result adds a contextual `[p]arts` action that restores
  UX-S55 without a draw while retaining `[r]esume` when incomplete and
  `[n]ext` as the explicit exit to the global forecast. Per-child show,
  update, move, archive, and supersede routes require an explicit resolved
  child reference in this multi-subject envelope and retain their existing
  typed previews. Escape or reverse navigation restores UX-S50 without an
  event.
- **UX-175 [core] — Part collection and results state the actual operation.**
  UX-B00 says `Break into parts` when the batch reclassifies the Brick and
  `Add parts` when its current Nature already supports them; empty Enter
  becomes available after respectively two or one drafts. UX-B01 names a
  Nature transition only when one occurs, names
  existing children as unchanged on addition, exposes any duplicate
  suspicion before commit, and conditionally states that current focus stays
  on the parent or that an obsolete scope-closure review will be invalidated.
  The accepted transaction is unchanged: no handle or child exists before
  `yes`. A Plan-origin acceptance reaches UX-S38 with an additive fact block
  containing the prior and resulting active-child counts plus every newly
  durable child. Direct `/break` and served-work `big` retain UX-B02, whose
  heading and consequence copy derive from `broken into` versus `added`, the
  resulting Nature, and whether finite scope review applies. Neither receipt
  draws nor focuses. Reverse navigation returns to UX-S55 when collection
  began there and otherwise to the exact prior checkpoint; only a served-work
  accepted break records `big`.
- **UX-176 [core] — Parts uncertainty explains the focus-unit distinction.**
  Question mark on UX-S55 opens UX-S56 and asks whether each intended item
  should be able to appear separately as Work. Yes returns to unchanged
  UX-S55; no returns to UX-S50 so `list items` or another structure may be
  chosen. Question mark shows one bounded consequence block: parts are child
  Bricks with their own importance, blockers, dates, and history; an active
  finite parent is not ordinarily suggested while unfinished parts remain;
  finishing them releases scope review rather than implicit completion; and
  ListEntries instead appear together through one owner. The same question is
  then asked once more. A second uncertainty response returns unresolved to
  UX-S50. Escape, Left Arrow, or empty-buffer Backspace restores UX-S55 from
  either question. No branch mutates, classifies, orders, or proposes a
  decomposition. Powered-up and Skill may use the existing attributed draft
  or mark one existing Parts action only; they cannot add a child, reorder
  human importance, skip the preview, or answer UX-S56.
- **UX-177 [core] — Incompatible parts ask only finite versus open-ended.**
  When MOD-062 says the current Nature cannot own parts, UX-S57 identifies the
  affected Brick and current Nature, then asks what happens after the current
  parts are finished. Its two consequence-first rows are `[f]inish one
  outcome` and `[k]eep accepting parts`, mapping only to `project` and
  `collection`; there is no default or nine-Nature chooser. Selecting a row
  records nothing, checkpoints that target, completes every available WRK-112
  builder and reconciliation, then enters UX-B00 when the affected Brick is
  the Structure subject, or UX-S58 when it is the proposed parent and the
  moving Brick itself supplies the first part. Question mark reuses the
  existing FED-025 finite-versus-continuing probe over this existing Brick:
  yes maps to the displayed continuing row and no to the finite row. The
  combined UX-B01 preview is the classification confirmation, so no separate
  Nature-confirmation toll intervenes. A second uncertainty response returns
  unresolved to UX-S50, or to UX-S52 when the affected Brick is a proposed
  parent. Reverse navigation follows the same origin; collector reverse
  restores the last UX-S57 checkpoint while provisional builder and
  reconciliation answers remain recoverable but uncommitted.
  List items use the parallel but independently worded lifecycle route in
  UX-181 rather than entering this parts question.
- **UX-178 [core] — Combined part preview discloses the whole behavior
  change.** When UX-B01 also changes Nature, it includes the same `From`, `To`,
  `Preserved`, `Will stop`, `Will start`, target configuration,
  reconciliations, focus/eligibility consequences, and origin consequence as
  UX-S47 before listing the pending child batch and provisional order. No yes
  action appears until every required choice has a supported resolution.
  `yes` remains the sole atomic Nature-plus-structure commit; `edit` returns
  to the nearest completed target builder or reconciliation using the existing
  preview-edit meaning; `no` and reverse navigation preserve the appropriate
  draft checkpoint exactly. Archived and active-stale origins carry their
  already-declared restoration or `out_of_date` consequence in the same
  preview. Scheduled-commitment preparation is already compatible, keeps the
  commitment as focus unit, and therefore adds parts without this Nature
  block or inferred relative timing.
- **UX-179 [core] — An incompatible parent preview names both subjects.**
  UX-S58 appears only after UX-S57 and all supported parent reconciliations.
  It leads with the proposed parent's complete UX-S47 behavior-change block,
  then shows the moving Brick's From/To composition, then the existing compact
  or mechanical Domain block. The unequal-Domain variant retains `[c]hange
  Domains...`; no separate edit action competes with reverse navigation to
  builders. Actions are `[y]es`, conditional change-Domains, `[n]o`,
  uncertainty, and the palette, without a default. Yes follows WRK-116; no
  restores UX-S52 with its exact query; reverse restores the nearest parent
  configuration checkpoint. Question mark opens UX-S59 and asks whether the
  proposed parent should become larger Work that owns the moving Brick as a
  separate part. Yes restores UX-S58, no restores UX-S52, and question mark
  shows one complete two-subject consequence summary before repeating once; a
  second uncertainty returns unresolved to UX-S52. All three reverse gestures
  restore UX-S58 from either question. Powered-up and Skill may mark one
  finite/open row and explain it, but cannot choose it, waive reconciliation,
  omit a subject, skip the combined preview, or accept either mutation.
- **UX-180 [core] — One checklist surface keeps item work fast and
  unambiguous.** UX-L01 composes the ListEntry manager, checklist Focus
  proposal, active run, and finite closure continuation without collapsing
  their discriminated payloads. Manager and active-run rows use stable
  insertion order and one cursor. Up and Down Arrow move it; Left and Right
  retain only the settled reverse/undo and forward/redo meanings. Number keys
  `1..9` select a visible row and never mutate it. `[d]one item` resolves the
  selected open entry in either state, `[a]dd item` opens one collector line,
  and explicit edit, cancel, or reopen actions operate only on the visibly
  selected row. There is no Space shortcut or action mode.

  During a run, a resolved or cancelled row stays in place with its outcome
  visible until the run finishes; repeated keystrokes therefore cannot target
  a row that shifted after mutation. A nine-row viewport, exact total and
  state counts, Up/Down, and PageUp/PageDown make a large set one semantic
  checklist surface without claiming every row fits on screen. Fresh manager
  views lead with open entries and may page closed history through ordinary
  `/show` or `/history`; there is no bespoke history action. The Focus
  proposal is the deliberate exception to direct `[d]one`: it exposes only
  `[y]es`, `[s]kip`, uncertainty, and the palette because item and terminal
  completion require their own honest scope. The active run exposes done item,
  add item, finish run, skip, and the palette; finish is unavailable before an
  item mutation and points to pause or skip instead of recording empty work.
- **UX-181 [core] — List-item setup and assistance preserve the dumb path.**
  A compatible empty owner opens the UX-L00 collector; a compatible nonempty
  owner opens UX-L01 manager. An incompatible owner asks `Should this list
  remain available after all current items are closed?` with `[y]es`, `[n]o`,
  and uncertainty, mapping to `living_checklist` and `finite_checklist` before
  WRK-112 reconciliation and one combined preview. Question mark asks whether
  new items are expected after the current set: yes returns to the continuing
  row, no to the finite row, and a second uncertainty explains both
  consequences once before returning unresolved to Structure. Reverse
  navigation restores the prior checkpoint and drafts without mutation.

  Global search gives no ListEntry a new sigil. A result renders its owner as
  `#handle "title"`, then the entry label and state; accepting it opens the
  owner surface with that row selected. Any command from the multi-row surface
  resolves and displays its Brick or local entry target before mutation.
  Powered-up and Skill may propose one attributed bounded entry batch from
  Raw, mark one existing lifecycle or manager action, and render a semantic
  suggestion beside the unchanged dumb choices. They may not resolve, cancel,
  reopen, edit quantity, finish a run, complete a checklist, or invent a unit
  conversion.
- **UX-182 [standard] — Responsibility uses one consequence-first builder.**
  UX-D02 begins with `Who should do this work?` and `[m]e`, `[s]omeone else`,
  and uncertainty, without a default. `someone else` reuses UX-075 and follows
  WRK-119. A fixed factory scope appears only as a preview fact; among resolved
  factory scopes, only `project` asks whether the target owns the Brick outcome
  alone or its current and future scope. The policy screen uses `[o]nce`,
  `[e]very review`, and
  `[n]o automatic follow-up`, with consequence copy and no default. Review
  delay uses `[o]ne day`, `[t]hree days`, `one [w]eek`, and `[c]ustom...`;
  three days is the visible factory default accepted by `*` or Enter. Handoff
  method lists only available adapters plus `[m]anually`; absence of an adapter
  is a normal one-choice screen, not an error.

  The final preview and proposed-state handoff screens always show the full
  rendered Brick, target, coverage, policy, review delay, handoff method, and
  editable message. Direct initial and take-back effect confirmations reuse
  UX-A01 without lottery skip. Manual confirmation asks whether responsibility
  has actually been handed off and explains that yes claims only that fact.
  Cancellation before handoff creates no message. Assisted modes may propose
  a target, scope, policy, delay, method, or text only as one attributed
  complete proposal; rejection returns to the unchanged dumb builder. They
  may not accept a field, approve an effect, record delivery or manual handoff,
  or activate responsibility.
- **UX-183 [standard] — Delegation reviews lead to typed reconciliation.** A
  selected internal review uses UX-D03 and offers progress update, reported
  complete, refused, no response, take it back, typed skip, and uncertainty.
  It never embeds a send button: a policy-permitted no-response result may
  transition to the separate UX-A01 effect approval. Progress and no-response
  results visibly name the next review instant. Reported completion shows the
  exact covered work still open before offering existing Nature closure;
  refusal uses UX-D04. Take-back and reassignment previews expose human-
  eligibility restoration, pending-effect rejection, new proposal facts, and
  any optional later message separately.

  The review uncertainty tree asks, in order, whether the target explicitly
  reported completion, explicitly declined, supplied a meaningful progress
  update, or supplied any response. Confirmed yes leaves map to the existing
  visible outcomes; confirmed no to all four maps to no response. A second
  uncertainty at a node shows the bounded evidence/history projection and
  returns unresolved without guessing. Project scope uncertainty asks whether
  current and future parts should remain the human's responsibility. Policy
  uncertainty first asks whether Little Ant may ever suggest a follow-up
  message, then whether it should do so at most once. Manual-handoff
  uncertainty asks whether the message or equivalent responsibility transfer
  was actually delivered. Every tree preserves reverse navigation and records
  nothing before a confirmed leaf.
- **UX-184 [core] — Feed and Raw triage preserve attention.** UX-I02 commits
  through FED-049 without a standalone receipt screen. A valid suspended Focus
  proposal or sober current-focus screen returns with one transient Feed fact;
  a stale proposal is recomputed, never accepted against an old revision. A
  no-envelope Feed invokes `next`. UX-T01 question mark follows FED-050, and
  UX-T02 always exposes standalone Raw as a concrete disposition rather than
  using indefinite skip. An accepted non-Work disposition reached from the
  idle lottery renders one compact result with `[n]ext`; when a current focus
  was preserved, it returns there with the result as a one-use fact. Powered-up
  and Skill may propose one attributed
  normalization or disposition only after the Raw commit; rejection restores
  exact dumb triage. They may not replace the Feed result, hold Raw durability
  behind a model call, or treat temporal proximity as consent.
- **UX-185 [core] — Work materialization stays lazy but commits atomically.**
  UX-T07 implements FED-051. Parent and Domain selectors appear automatically
  only with recorded candidates and otherwise remain available through edit.
  Neither phase nor effort is a creation toll. A duplicate suspicion uses
  UX-T08 before importance. Draft insertion uses the ordinary directional,
  skip, nearby-alternative, honest-answer, and contradiction grammar, but
  renders the unallocated side as `Proposed Work: "title"`. UX-T09 is the sole
  final confirmation and may mark yes as the mechanical default only after
  every shown fact and position is resolved. Acceptance renders one compact
  creation result with `[n]ext` and the palette; when a pre-existing current
  focus was transactionally preserved, it instead returns to that sober focus
  with the same compact creation fact once.

  Assisted modes may prefill and attribute title, Nature, Template,
  configuration, parent, Domains, duplicate candidate, and provisional order,
  and may use one UX-060 complete proposal. They cannot allocate a handle,
  convert AI order into human evidence, bypass a required builder or duplicate
  decision, accept their own proposal, or omit the final dumb-equivalent
  preview. Rejection returns to the earliest unresolved dumb fact with the Raw
  and draft checkpoint intact.
- **UX-186 [core] — Raw detail is a quiet action hub.** UX-RA00 renders the
  current original representation first, then current English normalization
  or its stale/missing state, followed by compact direct relationships,
  shelves, Domains, and sources. The primary keys invoke FED-052 one action at
  a time; there is no default mutation. A large payload is summarized with an
  explicit open/view action and never floods the terminal or operator context.
- **UX-187 [core] — Raw revision and link previews name every consequence.**
  UX-RA01 starts text selected, supports the external editor contract, and
  shows representation, prior/current digest, provenance, and affected direct
  consumers before commit. UX-RA02 chooses compatible general MOD-067 roles
  other than `duplicate_of`; that role uses UX-T10, while an existing relation
  remains inspectable and detachable with preview. Repeated uncertainty may
  inspect role consequences once, then
  leaves the decision pending. Powered-up and Skill may propose content or a
  role with attribution but cannot invent a consumer or bypass the same final
  preview.
- **UX-188 [core] — Translation keeps the dumb editor authoritative.** UX-RA03
  previews bulk scope before work begins and then presents one candidate at a
  time. A powered-up or Skill suggestion starts selected and includes its
  attribution; any ordinary typing replaces it, arrows preserve it for edit,
  and no opens the blank dumb editor. The result reports renamed title or
  same-Raw normalization, progress, and the next candidate without a second
  receipt screen.
- **UX-189 [core] — Source reconciliation never impersonates Work.** UX-RA04
  identifies source, observation outcome, and bounded difference before its
  exact same-Raw/new-derived-Raw/unrelated question. Missing or failed checks
  offer retry, pause, relocate, detach, or keep for later as applicable, never
  done or archive-by-inference. Effects and adapter errors remain visible even
  when the Raw has an attached Brick.
- **UX-190 [core] — No generic inherited mode exists.** Status `mode: dumb` or
  `mode: powered-up` describes only the current surface. Ancestor context is
  rendered under `Within`, while direct Domains and direct content/participant
  relationships retain their own labels. A child never displays an inherited
  requester, `about`, RawLink, or ambiguous `mode` fact.
- **UX-191 [core] — InteractionEnvelope has a closed transport shape.** Every
  envelope carries `interaction_id` (UUIDv7), positive `revision`, canonical
  `dataset_cursor`, `precondition_hash`, `grammar`, optional discriminated
  `opportunity`, canonical English `content`, ordered `actions`, ordered valid
  `commands`, optional `uncertainty_route`, bounded `context`, optional typed
  `progress`, `provenance`, and an integrity token. Each action carries stable
  ID, label, shortcut or native control, default status, consequence summary,
  and argument schema when needed. Presentation checkpoints carry their own
  ID and parent/forward links outside canonical domain state.
- **UX-192 [core] — Responses are bound and safely revalidated.** A response
  sends interaction ID, envelope revision, action ID, integrity token, and the
  answered dataset cursor. The dispatcher rejects an unknown identity,
  revision, action, or token. If the log advanced but the envelope's declared
  precondition hash is unchanged, it may revalidate and apply the exact action,
  returning the prior and accepted cursors. If relevant facts changed, it
  returns typed `stale_interaction` plus the replacement envelope and never
  carries the keypress, default, draft acceptance, or consent forward.
- **UX-193 [core] — Progress has three honest variants.** `finite` carries
  completed, total, and unit only when membership and total are stable;
  `recorded` carries a count and unit without a percentage; `range` carries a
  labeled lower and upper bound plus unit. Unknown progress is omitted. A
  changing adaptive queue, lottery, or open checklist never fabricates a
  total merely to fill these fields.
- **UX-194 [core] — Command availability is contextual and recoverable.** All
  non-input interaction and result screens expose `[/] more...`, except the
  startup splash, streaming progress, and a fatal startup error. UX-S09 keeps
  its settled `[/] menu...` label. Text editors keep slash literal under
  UX-022 and reach the palette by cancelling back to their owning screen;
  global `Ctrl-F` remains available. The palette lists only valid actions. A
  directly typed unavailable command returns its stable reason, nearest valid
  commands, and the unchanged or revalidated pending envelope.
- **UX-195 [core] — Guided arguments are schema-driven.** A command with a
  missing argument opens one input or selector per declared argument, in
  dependency order, and ends with the same preview as a complete command.
  Not-found and ambiguous references retain the query, show bounded typed
  candidates, and offer edit, search, or cancel. They never select the first
  fuzzy match, create an object, or discard a suspended interaction.
- **UX-196 [core] — Honest-answer routes use a closed family registry.** Every
  finite screen declares exactly one `uncertainty_route` from this table; no
  surface invents a local question-mark behavior:

  | Family | Deterministic dumb route |
  |---|---|
  | `understand_subject` | show bounded subject/context once, restate consequence, then answer or remain pending |
  | `binary_consent` | inspect exact effects and authority, ask whether those effects are intended, then yes/no or pending |
  | `classification` | use the registered capability tree for Nature/symptom; otherwise test displayed choices by observable consequence until one remains or pending |
  | `target_choice` | show why candidates qualify, search all compatible targets, create only when valid, then select or remain pending |
  | `proposal_text` | inspect source/difference, accept, edit, reject, or remain pending |
  | `date_time` | show temporal constraints, presets, custom selector, then choose or remain pending |
  | `observed_status` | ask only observable state questions, map the confirmed facts to an existing outcome, or remain pending |
  | `comparison` | use the relation's registered comparison aid; importance uses IMP-040..044 |
  | `reaction_choice` | ask which displayed consequence would help, eliminate choices one consequence at a time, then choose or remain pending |

  A node's question mark shows its alternate probe; after every declared probe
  has been used, another question mark leaves the original decision pending.
  `?` may act like a negative branch only when that exact node asks whether the
  human already knows or can observe a fact; it is never globally equivalent
  to no. An explicit `either order`/`does not matter` leaf remains available
  only in the importance aid and never means uncertainty.
- **UX-197 [core] — Undo targets one command group, not one low-level event.**
  Every successful mutator returns a `command_id`, typed `undo_class`, and
  opaque `undo_token` bound to its postconditions. `/undo` without an argument
  targets the latest uncompensated reversible command accepted by the same
  actor profile; history may invoke `/undo <command-id>` explicitly.
  Both paths show the same consequence preview. Read-only commands, draws,
  source observations, loader repairs, and received external facts are not
  undo candidates.
- **UX-198 [core] — Compensation classes are exhaustive.** The dispatcher
  validates the following closed matrix atomically; failure restores nothing
  partially:

  | Undo class | Compensation and precondition |
  |---|---|
  | `create` | retract the created command group only if every created record and relation has no later dependent mutation |
  | `value` | restore the prior scalar/revision/lifecycle value only if the current value is the command's post-value |
  | `relationship` | restore added/removed membership, link, annotation, ownership, or participant relation only if that exact relation has not changed |
  | `order_evidence` | deactivate or restore the command's comparisons, provisional position, confidence, and lazy markers only if no later accepted ordering command touches the affected sibling run |
  | `structure` | restore parent, children, Dependencies, and local positions only if affected nodes and cross-boundary relations have no later structural mutation |
  | `work_state` | restore lifecycle, execution, focus, WIP, occurrence/window outcome, cooldown, and pressure only if no later activity depends on the post-state and no other current focus would be displaced |
  | `gate_responsibility` | restore Wait or Delegation state, policy, spawned untouched follow-up records, and reviews only if no later observation, delivery, reassignment, or dependent action exists |
  | `batch` | apply every declared member compensation or reject the whole undo |
  | `external_effect` | before dispatch, withdraw the pending effect; after dispatch, require a separately modeled, previewed, approved compensating effect |

  Title and Raw revisions use `value`; Feed, decomposition, materialization,
  and checklist additions use `create` or atomic `batch`; skip evidence uses
  `work_state`; merge/supersede use `batch` with their declared transfer
  matrix. Compensating events preserve the original command and provenance.
- **UX-199 [core] — Redo is one checked branch.** A successful undo returns one
  redo token for that exact command group. Read-only commands and local
  navigation do not invalidate it; any later canonical mutation by any actor
  invalidates it unless its declared write set is disjoint and the original
  postcondition hash still validates. Redo re-runs current validation and
  reuses stored intent, never old external responses or stale provider data.
  Failure renders the typed UX-ER03 `redo_conflict` with inspect-current-state
  and stop actions.
- **UX-200 [core] — Errors have one sparse educational envelope.** Every
  failure carries stable `code`, human message, command/interaction identity,
  relevant subject/query, unchanged/advanced cursor, retry safety, bounded
  details, ordered recovery actions, and replacement InteractionEnvelope when
  applicable. V1 codes are `invalid_input`, `precondition_failed`,
  `not_found`, `ambiguous_reference`, `stale_interaction`, `conflict`,
  `redo_conflict`, `unsupported`, `permission_required`, `external_failure`,
  `corrupt_data`, and `unknown_event_version`. A failure never dumps a complete
  entity or stack trace into the ordinary surface.
- **UX-201 [core] — Human handles have deterministic edge normalization.** A
  seed is Unicode NFKD-normalized, combining marks removed, ASCII-lowercased,
  and split into nonempty ASCII alphanumeric tokens. One token uses at most
  its first 12 characters; several tokens use their first characters, at most
  12. If no token remains, the base is `brick`, `raw`, or `entity` by kind.
  MOD-010 collision suffixing then applies. This deliberately avoids
  locale-dependent transliteration. Displayed Unicode content remains intact.
- **UX-202 [core] — Technical records stay owner-addressed.** Bricks, Raws,
  and ExternalEntities alone have sigil handles. A Domain uses its quoted full
  path; a RawShelf uses `Shelf "name"`; a ListEntry is selected within its
  owner by stable local row and label; a Wait, Delegation, SourceBinding,
  occurrence, or effect is selected through its owning complete reference and
  typed local list. Technical JSON and diagnostics expose their UUIDs. The UI
  never creates memorable global sigils merely to address implementation
  records.
- **UX-203 [core] — Reference ranking and parsing never guess.** Typed
  selectors rank exact handle, exact canonical label, prefix, token, then fuzzy
  matches; ties use current parent, direct Domain overlap, most recent direct
  interaction, canonical label, then UUID. Parent search additionally excludes
  invalid/cyclic targets before ranking. In a declared CLI reference argument,
  an exact current sigil handle resolves and a pasted complete citation checks
  its quoted label for staleness. In prose/input fields, sigils and action
  letters remain literal until explicit autocomplete selection. Ambiguity
  opens UX-RF04; it never resolves by list position.
- **UX-204 [core] — `lant` is the sole executable name.** V1 documentation,
  scripts, protocol examples, and error recovery use `lant`. `la` is retired,
  not a core alias or packaging shim. Operator natural-language interpretation
  may map a user's words to `lant` commands but always renders the canonical
  command it invoked.
- **UX-205 [core] — Domain focus asks for duration, not ontology.** The REPL
  command is `/domain-focus`; the CLI equivalent is `lant domain focus`. After
  one complete path is selected, UX-DM00 asks whether to draw one suggestion,
  stay within until cleared, or merely prefer the Domain. No option is a
  default. The first two immediately invoke `next` under FOC-057; prefer
  returns one compact result without drawing. Powered-up and Skill may propose
  one path with attribution but preserve this duration choice.
- **UX-206 [core] — Hard scope is quiet but never hidden.** While stay-within
  is active, every ordinary screen adds one dim secondary fact immediately
  above the fixed footer: `Within Domain: <complete path> · until cleared`.
  It does not replace the subject's direct Domain line. A blocker redirect
  outside that path adds the concise primary-context fact `Needed for scoped
  Work in: <path>` and the full chain remains under question mark.
- **UX-207 [core] — Empty scope offers only real recoveries.** UX-DM01 names
  the complete scope and separately counts blocked, temporal, waiting,
  delegated, dormant, and absent Work when those counts are nonzero. It offers
  review gates only when a review is actionable, contextual Feed with the
  Domain merely proposed, choose another Domain, and leave scope. It never
  falls through to global `next`; repeated uncertainty uses UX-196
  `reaction_choice` and may honestly remain here.
- **UX-208 [core] — Change-subject edge cases stay on one screen.** UX-DM02 is
  the zero-target variant of UX-S09. It keeps the original Brick and symptom,
  says no other subject currently has executable Work, offers organize and
  review only when FOC-061 has a candidate, then skip anyway, back, and
  uncertainty. A no-Domain source uses ordinary target pages but receives no
  fatigue claim. A multi-Domain source displays the one path already recorded
  by the draw; question mark may show the alternatives without changing it.
- **UX-209 [standard] — Domain maintenance is consequence-first.** UX-DM03
  uses complete old/new paths and direct/descendant/unique counts for create,
  rename, move, merge, archive, and restore. Merge names the surviving identity
  and conflicts; archive names active-focus/scope clearing; move names every
  changed descendant path. Membership management stays on Brick/Raw detail.
  There is no generic taxonomy editor, exclusion toggle, or multi-taxonomy
  selector.
- **UX-210 [core] — Forecast inspection distinguishes order from chance.**
  The `focus forecast` branch of `/list` shows the selected scope, current
  positive chance, strongest
  signal, bounded bonuses, age, effective Domain path, blocker endpoint, and
  opportunity variant without exposing a fake public score. It may list or
  inspect probabilities without drawing. Its starvation wording says `chance
  increases with age`, never `guaranteed by`, because FOC-059 deliberately has
  no deterministic service deadline.
- **UX-211 [core] — Served-work symptoms do not branch by Nature.** Every
  FOC-037 execution variant renders UX-S01 unchanged. Its `done` action follows
  WRK-123 and its committed reaction follows WRK-124; those typed transitions,
  not another visible symptom taxonomy, preserve Nature-specific truth. An
  unavailable recovery explains its exact precondition and restores the same
  reaction screen. Powered-up and Skill may mark one existing reaction but
  cannot remove a symptom, invent a Nature-specific shortcut, or reinterpret
  one key.
- **UX-212 [core] — Empty easier-work recovery keeps the pending symptom.**
  UX-S08E replaces, rather than follows, an empty shortlist. It carries the
  uncommitted `tired` origin and offers only canonical recoveries that are
  currently usable. Back returns to UX-S07; no action is a default. A selected
  route commits at its established reaction boundary, never when this factual
  screen appears.
- **UX-213 [core] — Short-sprint custom input is bounded.** UX-S15A is a
  single numeric editor labeled `Minutes (1–120)`. Enter validates and opens a
  start preview containing duration and absolute end time; it does not start
  focus. Escape or empty-buffer Backspace restores UX-S15. Question mark on
  the duration menu explains the three factory choices and returns there; it
  never guesses a custom value.
- **UX-214 [core] — Date/time input uses one portable component.** UX-DT00
  renders caller-owned presets with complete absolute local date and time,
  then `choose another...` and uncertainty. UX-DT01 collects a numeric civil
  date and clock time with the caller's suggested time visible and editable;
  UX-DT02 previews local date, time, zone, UTC offset, and resulting purpose
  before confirmation. Time-zone autocomplete appears only when changed from
  the visible profile zone. There is no natural-language parser, silent
  operational-day rounding, or commit before UX-DT02.
- **UX-215 [core] — Out-of-date uncertainty has one exact decision tree.**
  Question mark on UX-S35 asks, one screen at a time:

  ```text
  Q0. Has the intended result already happened?
  ├─ yes → done through UX-S01
  └─ no
     Q1. Would you still choose to pursue the same intention?
     ├─ no  → archive it
     └─ yes
        Q2. Is newer Work now responsible for that intention?
        ├─ yes → replaced by newer Work
        └─ no
           Q3. Would revising this Brick make it usable again?
           ├─ yes → update it
           └─ no
              Q4. Do you only want to postpone it without changing it?
              ├─ yes → skip anyway
              └─ no  → out of date was not confirmed; restore UX-S01
  ```

  Every action leaf is confirmed in the ordinary UX-S01 or UX-S35 grammar
  before a mutation. The final no is an event-free classification result, not
  `other` evidence. Question mark at a node uses UX-196's alternate probe
  once; repeated uncertainty leaves the original decision pending.
- **UX-216 [core] — Update uncertainty tests observable consequences.**
  Question mark on UX-S37 asks this exact sequence until one purpose remains:

  ```text
  Q0. Is its short name or explanation stale?              yes → meaning
  Q1. Does the kind of Work need to change?                 yes → behavior
  Q2. Is its parent, parts, blocker, wait, or responsibility stale?
                                                            yes → plan
  Q3. Are its dates, schedule, or repetition stale?         yes → timing
  Q4. Are its Domains, people, or companies stale?
                                                            yes → context
  Q5. Is linked material or its external origin stale?      yes → source material
  Q6. Do you need to inspect the complete Brick first?      yes → view everything
                                                            no  → no update identified
  ```

  A no advances; a yes restores UX-S37 with the corresponding row visibly
  suggested from those answers, where the human still confirms it. `no update
  identified` restores UX-S37 event-free. Node uncertainty uses UX-196 and may
  remain pending.
- **UX-217 [core] — Typed update submenus contain only human consequences.**
  UX-UP00..UP02 render WRK-128's timing, context, and source-material choices.
  Each row includes one short consequence, applies only when its canonical
  manager is valid, and has no dumb default. Uncertainty uses the same
  observable wording as UX-216 restricted to that submenu. An assisted mode
  may mark one row with attribution but reaches the identical typed manager
  and preview.
- **UX-218 [core] — Parent archive begins with visible scope.** UX-LC00 appears
  only when the selected Brick has direct children. It explains `this Brick
  only` as moving those children one level up and `entire subtree` as
  archiving active descendants. Neither row is a default. Selection enters
  WRK-129 gate reconciliation and the complete MOD-088 preview; it does not
  mutate structure while browsing.
- **UX-219 [core] — Scope closure shows terminal counts before asking.**
  UX-LC04 uses `Review:` and lists done, archived, superseded, merged, missed,
  and cancelled child counts, including zero only when it clarifies the total. It offers complete
  parent, review outcomes, add more work, lottery skip, and uncertainty.
  Completion has no default even when every child is done.
- **UX-220 [core] — Duplicate review distinguishes sameness from
  replacement.** UX-LC01 asks how two existing Bricks are related and offers
  merge as `the same Work was recorded twice`, supersede as `newer Work
  replaced older Work`, and keep separate. The shortcut and explanation are
  stable across direct, duplicate-review, Raw, and import origins. Question
  mark uses one observable test: whether completing either record would have
  fulfilled the same intention at the time both were active.
- **UX-221 [core] — Lifecycle previews lead with human outcomes.** UX-LC02
  leads with survivor and absorbed Work, then combined, retained, selected,
  and stopped facts from MOD-086. Supersede leads with old and replacement
  Work, then child disposition and each explicit MOD-087 choice. Archive leads
  with selected scope, moved or archived child counts, live-gate outcomes, and
  focus effect. Technical UUIDs and empty categories are omitted from ordinary
  rendering. Every preview offers yes, edit, no, and uncertainty with no dumb
  default; `--dry-run` renders the same content without actionable yes.
- **UX-222 [core] — Lifecycle conflict resolution is one question at a
  time.** UX-LC05 renders the selected operation, progress, one conflicting
  fact, and only its valid typed resolutions. It reuses Nature, move,
  Dependency, Wait, Delegation, effect, source, and date managers rather than
  defining a generic conflict editor. Back discards the whole pending
  lifecycle draft. After the final resolution it opens the complete preview.
- **UX-223 [standard] — Assistance may explain but not broaden lifecycle.**
  Powered-up and Skill may suggest merge versus supersede, survivor,
  replacement, archive scope, or one existing conflict action with concise
  attribution. A rejected proposal returns to the exact dumb screen. No mode
  may infer external cancellation, select a terminal outcome, transfer a
  relationship, or approve a batch silently.
- **UX-224 [standard] — Impact begins with a plain class ladder.** UX-J00
  renders the selected root, asks how much difference its outcome is currently
  expected to make after accounting for uncertainty, and shows all six IMP-018
  classes with short semantic anchors. No class is preselected. Selecting one
  opens UX-J01, where
  `speculative` is the visible default only when no evidence has been selected;
  it never acts as a class default. A child invocation first cites its root and
  offers to inspect or classify that root rather than accepting a child value.
- **UX-225 [core] — Impact comparison names both directions.** UX-J02 uses two
  complete root citations and the exact actions `[m]ore impact`, `[l]ess
  impact`, `[a]bout the same`, `[s]kip`, and uncertainty. Like importance, it
  uses named directions instead of yes/no. Unlike importance, `about the same`
  is valid class-band evidence under IMP-050. A provocative impact comparison
  is visually identical; contextual inspection alone reveals its inferred
  path and validation purpose.
- **UX-226 [standard] — Maturity asks about selected evidence, not belief.**
  UX-J03 shows one selected attached Raw or completed validation Brick and one
  IMP-051 question per screen. Search and autocomplete may add or replace the
  evidence item without leaving the flow. The leaf previews class, proposed
  maturity, relied-upon evidence, and applicability assertion before yes,
  edit, no, and uncertainty. No evidence item means only `SPECULATIVE` is
  available. A maturity-review opportunity uses the same ladder and clearly
  states why review became due.
- **UX-227 [standard] — Effort begins with a complete profile ladder.** UX-J04
  renders all eight IMP-024 classes and the realistic hours from the active
  profile. It asks for total current-scope effort from start to finish, labels
  hours as planning references, and has no default. Question mark enters the
  exemplar route in UX-J06; when no suitable exemplar exists it explains that
  briefly and returns to the same unmodified ladder. Missing effort is never
  displayed as normal.
- **UX-228 [core] — The lottery effort question is a small easiest-choice.**
  UX-J05 shows two to four comparable work units as numbered complete Brick
  citations and asks which looks easiest to complete. It has no default,
  class, hour value, or hidden winner. Selection records IMP-054 relative
  evidence and ends the lottery interaction with one compact receipt. Skip
  applies typed comparison cooldown; uncertainty explains scope and may inspect
  each Brick but does not turn tiredness or current preference into effort.
- **UX-229 [standard] — Exemplar assistance remains a comparison.** UX-J06
  compares one subject with one reviewed exemplar and exposes `[m]ore effort`,
  `[l]ess effort`, `[a]bout the same`, `[s]kip`, and uncertainty. The exemplar
  displays its class and realistic planning reference. Accepted answers move
  directly to the next exemplar without a receipt; after at most three, the
  flow proposes one isolated class or shows only the remaining classes. The
  final class still requires the ordinary explicit confirmation.
- **UX-230 [core] — Non-importance contradictions preserve a third answer.**
  UX-J07 shows absolute-time evidence and offers `[c]hanged`, `[r]evise
  answer`, and uncertainty. `Revise answer` returns to the original three-way
  comparison rather than assuming the opposite direction. The uncertainty
  aid asks the IMP-055 axis-specific three-way question and includes `[a]bout
  the same`; it never uses urgency, current mood, or an importance winner as a
  proxy. A still-uncertain result keeps the last coherent judgment and exposes
  no confidence float.
- **UX-231 [standard] — Judgment results are compact and attributed.** UX-J08
  reports the resulting class and maturity or confidence label once, then
  waits at the ordinary result boundary. A relative comparison receipt says
  only `Impact comparison recorded` or `Effort comparison recorded`. Relevant
  views render `Impact: HIGH · supported`, `Impact: HIGH · supported · from
  #root`, `Effort: EASY (~6 work hours) · reviewed`, `provisional · assisted
  by <provider>`, `review due`, or `not classified · N comparisons` as
  applicable. Empty optional axes remain omitted elsewhere.
- **UX-232 [standard] — Assistance compresses only the declared judgment
  route.** Powered-up or Skill may precede UX-J00 or UX-J04 with one attributed
  class-and-evidence proposal under UX-060, or mark one existing comparison
  action under UX-059. Rejection reaches the exact dumb ladder or comparison.
  Assistance cannot claim evidence maturity without selecting inspectable
  evidence, convert hours into canonical state, suppress contradiction review,
  or approve a judgment silently.
- **UX-233 [core] — Judgment uncertainty is bounded and axis-specific.** On
  UX-J02, question mark checks whether each outcome is understood, offers
  read-only evidence inspection, then asks whether A, B, or neither has a
  materially larger expected effect; the last branch offers
  `about the same`, explicit investigation Work, or typed skip. On UX-J05 it
  first explains total current-scope effort, then offers inspection of one
  candidate or typed skip; it does not manufacture an easiest answer. On
  UX-J00 and UX-J04 it offers the applicable reviewed exemplars and, when none
  exist, leaves the value unclassified. UX-J03 follows IMP-051 exactly.
  Repeated uncertainty preserves the pending review or returns to the direct
  caller without evidence, class, cooldown, or invented middle value.
- **UX-234 [standard] — Judgment commands are narrow.** The REPL exposes
  `/impact #brick`, `/effort #brick`, and their contextual palette entries.
  The CLI exposes `lant impact set|clear|show`, `lant effort set|clear|show`,
  and read-only comparison/evidence inspection; guided missing references use
  the ordinary `#` autocomplete. Mutating forms support `--dry-run`, require
  the same previews as the REPL, and define no `weight`, `estimate-hours`, or
  child-impact aliases. Relative lottery comparisons remain opportunities,
  not commands that an ordinary user must memorize.
- **UX-235 [core] — Wait pressure never changes the Wait question.** UX-W01
  keeps its sober `Review:` composition at every age. It may show `Waiting
  since`, prior review count, and unanswered follow-up count in secondary
  context, but never `due`, `overdue`, a numeric score, a countdown, or urgent
  personality copy. Forecast inspection may explain the bounded WRK-134 terms.
  The primary actions remain identical until WRK-137 deliberately switches to
  UX-W03.
- **UX-236 [core] — Source-observed Wait resolution cites the observation.**
  UX-W02 leads with the affected Work, waiting target/condition, source, and
  observed fact. It uses the Wait-kind-specific positive label, keep waiting,
  inspect evidence, typed skip, and uncertainty. There is no dumb default.
  A trusted source or assisted mode may mark the positive row with `*` and one
  attributed explanation; rejection or keep-waiting preserves the exact Wait
  gate and does not start ordinary Work.
- **UX-237 [core] — Repeated follow-up becomes one strategy screen.** UX-W03
  appears after WRK-137's soft cap and explains that two follow-ups were
  recorded without a meaningful response. Its rows are wait longer, follow up
  again, change what is blocking it, stop waiting, skip, and uncertainty, each
  with one short consequence. Nothing is selected. Follow up again reuses the
  existing enabling-Brick and effect path; stop waiting previews release of
  only this Wait and never claims response or completion.
- **UX-238 [standard] — Focus commands reuse the screens people already
  know.** `/focus` reaches ordinary `Focus?` or the current-focus continuation;
  `/pause` reaches UX-F06; `/return-to-idle` reaches UX-F15; `/done` dispatches
  through the Nature-owned result; `/finish` reaches only the active checklist
  finish surface; and `/archive` reaches the lifecycle preview. The palette
  displays only valid commands and short human consequences. Unknown natural
  aliases receive one educational suggestion rather than mutating state.
- **UX-239 [standard] — Repeatable completion separates the run from its
  return.** After run completion, UX-REP00 says `Run completed:` and shows the
  same Brick, prior run count, and current return policy. Existing policy is a
  visible default; a first policy has none. The choices keep/change return,
  manual only, archive, and uncertainty. No row creates another Brick,
  reinserts importance, calls the run missed, or changes history. Leaving the
  screen preserves a completion-result continuation, not an immediately
  drawable repeatable run.
- **UX-240 [standard] — Repeatable return input is structured and previewed.**
  UX-REP01 edits center, unit, and optional variation as separate fields, shows
  one plain-language example plus the earliest/latest possible return, and
  previews the policy before acceptance. Digits edit numeric fields; unit is a
  finite selector. Dumb mode never parses `six-ish months` or asks an LLM.
  Assisted modes may propose complete values with attribution and the same
  preview.
- **UX-241 [core] — Habit outcomes use calm factual language.** UX-H00 renders
  `Habit recorded:`, the habit citation, `Completed` or `Not completed in this
  window`, and the compact outcome strip. An explicit unfulfilled action that
  would end a visible streak first uses corrected UX-P01; deterministic expiry
  records truth and may show one discreet notice later, never a retroactive
  confirmation. The screen performs no automatic draw and offers next plus the
  palette. Glyph-free mode uses `done` and `unfulfilled` words.
- **UX-242 [standard] — Habit introspection begins from observed history.**
  UX-H01 shows only the bounded outcome/skip evidence that crossed WRK-145's
  threshold, then offers inspect reasons, adjust schedule, add enabling work,
  pause, archive, keep unchanged, skip, and uncertainty. No cause is written in
  advance. Selecting inspect opens history and returns; every mutation reaches
  its existing typed preview. Keep unchanged resolves this review only; skip
  preserves it with cooldown.
- **UX-243 [standard] — Assistance never moralizes standing work.** Powered-up
  or Skill may mark one existing Wait strategy, return policy, or habit remedy
  and explain cited history. It cannot invent a response, send a follow-up,
  classify an expired window as blocked, modify a streak, or archive standing
  Work silently. Its rejection path is the identical dumb screen, and its copy
  may not use guilt, failure, laziness, or health claims.
- **UX-244 [core] — A notice stays secondary until opened.** The persistent
  frame renders at most one dim notice line and `+N notices` above its status
  block. Selecting it or `/notices` opens UX-NOT00 with the complete subject,
  temporal fact, absolute local instant, and `[o]pen Work`, `[a]cknowledge`,
  `[s]nooze`, and uncertainty. No action is selected. Acknowledge and snooze
  render one compact no-draw receipt and return to the prior revalidated screen.
  The notice never borrows ordinary lottery skip or personality copy.
- **UX-245 [standard] — Obligation occurrences look like Work, not a queue.**
  An atomic occurrence uses UX-RO00's ordinary `Work:` and `Focus?` grammar,
  then shows `Occurrence:` and its series citation in secondary context. An
  exact-time occurrence uses UX-SC02..SC04 with the same series citation and
  occurrence label. Repeated titles are left intact. Contextual inspection
  explains the nominal anchor and dates; every action affects only this
  occurrence. The surface never says FIFO, next occurrence, or inserts an
  importance comparison among occurrences.
- **UX-246 [standard] — Recurrence input is finite and mechanical.** UX-RO01
  selects daily, weekly, monthly, or yearly, then shows only the fields required
  by WRK-148: occurrence Nature, interval, times, zone, family anchor,
  scheduled duration when applicable, and explicit temporal offsets. Numeric
  and finite-choice input replaces recurrence prose. The
  preview shows the next three nominal anchors and effective not-before,
  best-before, and deadline values before acceptance. Unsupported imported
  rules stop with preserve-as-Raw or reviewed finite-expansion recovery.
- **UX-247 [core] — Commitment creation names the full interval.** UX-SC00
  collects start date/time/zone and end date/time/zone as separate structured
  fields and previews both absolute instants, duration, Place/source links,
  and any overlap. No exact end means no Brick. UX-SC01 then previews every
  Template-proposed preparation child and relative constraint as an editable
  batch; accepting interval and preparation is one creation transaction.
- **UX-248 [core] — Active commitment grammar contains no skip.** UX-SC02
  leads with `Commitment:` and the live interval, then offers attend now,
  missed, cancelled, and uncertainty. Once focused or after the interval ends,
  UX-SC03 offers attended, missed, cancelled, and uncertainty. Generic Focus,
  done, pause, later, and skip are absent from the primary actions. Every
  terminal result names the truthful outcome and waits at next plus palette.
- **UX-249 [core] — Current focus and overlaps remain visible.** When ordinary
  Work is current, UX-SC02 shows that complete citation in secondary context
  and explains that attend now will leave it WIP. UX-SC04 lists two to six
  active overlapping commitments with numbered citations and full intervals;
  more are paged without default or draw. Choosing one opens its unchanged
  commitment screen, and resolving it returns to the remaining set. Known
  overlap during creation/reschedule uses keep both, edit interval, or cancel
  with no default.
- **UX-250 [core] — Reschedule preview leads with changed human consequences.**
  UX-SC05 shows old/new interval, then relative pending children that move,
  completed children that remain historical, explicit absolute overrides that
  remain unchanged, newly passed preferred/deadline facts, and focus/WIP
  choices. Edit reaches the exact interval or child constraint. Yes is one
  MOD-088-style batch; no restores the old anchor; uncertainty inspects why a
  child changed without choosing. Assisted and source-originated reschedules
  use the same preview and cannot approve it.
- **UX-251 [standard] — Temporal assistance is attributed compression only.**
  Powered-up or Skill may propose one exact interval, recurrence rule,
  preparation batch, notice action, or overlap choice reachable through the
  dumb screens. The proposal cites title/metadata, Template guidance, source,
  or history and uses UX-060. Rejection restores the original mechanical
  fields. Assistance cannot turn an all-day event into an interval, invent an
  end time, mark attendance, suppress an overlap, or reinterpret one temporal
  meaning as another.
- **UX-252 [standard] — Phase is always text first.** Phase is rendered with
  MOD-018's English label in every compact row, detail view, selector, and
  projection. The factory icon may precede the label but never replaces it.
  UX-PH00 is the single dumb phase selector used by lazy review and `/update`;
  it has no phase default, mandatory progression, or automatic transition.
  Assisted modes may mark one existing row as suggested with attribution, but
  only the human's accepted row becomes a direct claim.
- **UX-253 [core] — Decoration is removable without loss.** The terminal
  renderer supports `emoji_mode = auto | always | never`. Auto requires an
  interactive UTF-8 surface with a declared reliable display-width policy;
  otherwise it behaves as never. Never suppresses only decorative emoji and
  repairs adjacent whitespace. It retains all words, shortcut brackets,
  punctuation, ASCII cursor markers, warnings, history cells, and statuses.
  Emoji mode is independent of ANSI color mode. Local-web, future conforming
  mobile, and accessible renderers expose the same semantic text even when
  they choose a different decorative representation.
- **UX-254 [core] — Shortcuts are unique per screen, not globally.** Within one
  pending finite screen, every visible one-key action has a distinct key. The
  allocator first keeps canonical meanings from UX-014, then an unused natural
  initial, then an unused visible in-word letter. If wording can name the
  consequence more clearly, it changes the action label before taking an
  awkward in-word letter. Number keys belong to dense candidate lists, not to
  stable semantic verbs. Reuse on another screen is allowed and preferred when
  the same obvious word returns. `?`, `/`, `*`, Enter, Escape, Backspace, and
  arrows retain their declared control meanings and are never action letters.
- **UX-255 [core] — Selection has one visible ASCII cursor.** Every
  arrow-navigable result or palette row reserves a two-cell prefix: `> ` for
  the selected row and two spaces for every other row. Capable ANSI rendering
  additionally applies reverse video to the selected row; it never removes
  the cursor. Therefore stripping style preserves the same columns and
  selection. `*` remains the separate default marker on finite action choices
  and never means cursor position. A selected prefilled text buffer follows
  UX-077 and does not borrow the row cursor.
- **UX-256 [core] — Narrow layouts reflow; they do not abbreviate meaning.** At
  widths where an approved action row or aligned footer would wrap
  ambiguously, actions render one per line in canonical order, then the palette
  escape. Candidate rows remain one per line. Long titles and Domain paths use
  hanging continuation indentation; the handle remains on the first line and
  every path segment remains present. The three footer blocks retain their
  order but may drop alignment padding. No horizontal scrolling is required
  for a decision, no action label is truncated, and a renderer may paginate
  only a declared candidate collection—not the current question or actions.
- **UX-257 [core] — Input and choice never masquerade as each other.** A text
  input always shows the `› ` edit prompt, cursor, Enter/Escape hint, and the
  dumb English-writing reminder when UX-049 applies. A finite choice has no
  edit prompt and reacts to one visible key. Search and autocomplete are input
  followed by a cursor list; typing edits the query, Up/Down moves the `>` row,
  Enter chooses it, and Escape returns. A screen cannot accept both arbitrary
  text and hidden one-key semantic actions in the same input state.
- **UX-258 [core] — Assistance and navigation labels stay literal.** The
  canonical finite uncertainty label is always `[?] I don't know`; product
  help is always `/help`; the global secondary escape is `[/] more...` except
  on UX-S09 and UX-T02, whose local candidate pagination requires the declared
  `[/] menu...`; and an explicit local return is `[b]ack`. A candidate
  paginator says `[m]ore options...`, `[m]ore matches...`, or another
  collection-specific literal already declared by its screen, so it cannot be
  confused with the command palette. Empty or terminal result screens name
  `[n]ext` only when they truly invoke the global forecast. Labels such as
  `help`, `other`, `none`, `more`, and `skip` are never treated as synonyms.
- **UX-259 [standard] — Factory personality text is closed and inspectable.**
  The exact 64 English phrases and stable IDs live in
  [`personality-catalog.md`](personality-catalog.md). The factory count remains
  exactly 16 per UX-064 intent. Dumb mode selects only from that file;
  powered-up and Skill paraphrase only under UX-065. Disabling emoji removes
  the catalog's declared prefix/suffix decorations but leaves its wording.
- **UX-260 [standard] — Contact selection stays human-facing.** A flow that
  needs a delivery target first resolves the person or company through UX-075,
  then renders only usable delivery choices through UX-CNT00. Each automatic
  row names the contact value, adapter/account label, and purpose in ordinary
  words; `ContactPoint`, `DeliveryBinding`, credential slot, and component key
  remain inspection details. Manual handoff is always available. Only a
  purpose-scoped preferred ready binding may carry `*`; otherwise manual is
  the visible safe default.
- **UX-261 [standard] — Contact maintenance is separate from sending.**
  `/update @entity contacts` opens UX-CNT01. Adding or revising a contact
  previews the exact kind, value, source, and affected local delivery bindings.
  Accepting changes only contact data; it neither creates a binding, verifies
  delivery, sends, delegates, nor retries an effect. Retiring an in-use contact
  first requires choosing replacement bindings or leaving them explicitly
  unavailable.
- **UX-262 [standard] — Unlock returns to the same approval.** UX-VLT00 names
  the integration purpose and account that need credentials without exposing
  a secret or technical slot. `[u]nlock` enters a no-echo passphrase field;
  success returns to the exact prior effect/source preview still awaiting its
  original approval. Another method and later remain owning-flow actions, not
  vault outcomes. A failed attempt returns to the same screen and creates no
  domain event, provider failure, or permanent lockout; the scrypt work factor
  already supplies the offline and interactive attempt cost.
- **UX-263 [standard] — Configuration is inspectable by concern.** `/config`
  opens UX-CFG00 with presentation, calibration, integrations, vault, profile,
  and resolved-path sections. Each section validates and writes only its typed
  file; the screen never presents one giant YAML editor. `lant config show`,
  `lant config paths`, and `lant config validate` provide sparse, redacted
  equivalents. Secret entry and unlock stay under `/vault`, never `/config`.
- **UX-264 [standard] — Secret input cannot become transcript.** No-echo input
  shows only a fixed prompt and attempt outcome. It is excluded from UI
  checkpoints, recent actions, history, shell-completion logs, crash recovery,
  clipboard helpers, powered-up/Skill context, and external editors. Back or
  Escape clears the whole buffer. Paste may be disabled by the terminal host;
  the canonical protocol never echoes length or characters.
- **UX-130 [core] — Every uncertainty route is declared.** Every finite screen
  that exposes `[?] I don't know` registers a bounded UX-016 tree in the same
  versioned interaction grammar as its ordinary choices. Each leaf identifies
  either one existing canonical answer or one concrete recovery; a free-form
  model answer, generic explanation page, silent default, and unbounded chat
  are not valid dumb-mode leaves. A 1.0 flow is incomplete until its ordinary
  choice, every uncertainty leaf, confirmation boundary, and reverse path have
  a dumb replay. Trees may share existing selectors and builders rather than
  duplicate domain behavior. Older screen-specific rules that describe a
  direct uncertainty consequence settle only an allowable leaf; they do not
  bypass this tree and confirmation contract. UX-196 supplies the closed
  family registry for every remaining finite screen.
- **UX-131 [core] — Served-work uncertainty uses mechanical discrimination.**
  Question mark on UX-S01 opens UX-S33 and traverses the exact WRK-095 tree one
  binary question at a time. The questions seek the principal obstacle for
  this interaction; they do not assert that another symptom could never also
  apply. `yes` reaches the current node's leaf, `no` advances to the next
  distinction, and the final `no` reaches `other`. No category menu or hidden
  probabilistic classifier replaces this tree in dumb mode.
- **UX-132 [core] — A symptom leaf is confirmed before reaction.** Reaching a
  symptom leaf opens UX-S34 with the symptom, its decisive behavioral reason,
  and `[y]es · [n]o · [?] I don't know`. The mechanically derived `yes` is the
  visible default. `yes` opens that symptom's existing reaction without yet
  recording evidence; for `other`, it opens UX-S31. `no` restores UX-S01 so
  the human can select directly. Uncertainty restarts UX-S33 at its first
  question. Reverse navigation returns to the decisive tree question.
- **UX-133 [standard] — Assisted trees preserve the dumb protocol.** Skill or
  powered-up mode may mark at most one existing `yes` or `no` answer with `*`
  and add one concise attributed reason under UX-059. It still presents every
  accepted question, confirmation, and canonical reaction boundary. It cannot
  collapse the tree into an unreviewed classification, add a branch, answer on
  behalf of the human, or turn model uncertainty into core evidence.
- **UX-134 [core] — Importance uncertainty begins with understanding.**
  Question mark on UX-O01 opens UX-O11 at IMP-040 Q0. Every Q0..Q8 screen
  retains the two complete Brick citations and ordinary footer but shows only
  one binary question. It has no inferred direction, equality, urgency,
  impact, or model-selected answer. Reverse navigation restores the preceding
  question and, from Q0, the exact pending UX-O01 comparison.
- **UX-135 [core] — Convergent navigation preserves meaning.** When IMP-041
  permits question mark and `no` to reach the same next screen, the envelope
  preserves which local answer occurred even though neither becomes a domain
  event. A later branch may rely only on an explicit `yes`; it cannot reinterpret
  an earlier uncertainty as rejection. The UI keeps the ordinary
  `[y]es · [n]o · [?] I don't know` grammar and does not disclose technical
  transition-policy names.
- **UX-136 [core] — Importance leaves preview their exact effect.** A direct
  A/B result opens UX-O12; `either_order` opens UX-O13; investigation opens
  UX-O14; and provisional placement opens UX-O15. Each preview names what will
  be recorded and what will remain unresolved, exposes a visible default only
  when mechanically derived from the accepted tree, and returns to its
  decisive question on reverse navigation. No tree question, context view, or
  unaccepted leaf changes order, evidence, review pressure, or random state.
- **UX-137 [core] — Inspection and investigation remain ordinary tools.** A
  context-inspection leaf opens the existing read-only `/show` projection for
  exactly A or B, then returns to Q0 or Q2 without losing the comparison.
  Investigation uses UX-O14's dumb English input and the contextual
  Raw-backed Work preview before creating a Brick. Its final preview visibly
  links the new Brick to the A/B importance review without claiming a
  Dependency on either Brick.
- **UX-138 [standard] — Assisted importance remains advisory.** Skill or
  powered-up mode may summarize existing context, mark one current binary
  answer, or propose one investigation method and title with attribution. It
  may suggest `either_order` when evidence supports indifference, but must
  traverse the same confirmation and cannot record a direction, symmetric
  evidence, provisional position, or investigation Brick automatically.
- **UX-139 [core] — Focus uncertainty starts with the work itself.** Question
  mark on UX-F01, UX-F02, or UX-F03 opens UX-F12 at FOC-048 Q0. Each question
  retains the complete proposed Brick citation and ordinary footer while
  preserving cross-Domain and blocker-path context. Reverse navigation from
  Q0 restores the exact proposal without a draw or revision change.
- **UX-140 [core] — Missing understanding reuses context and vague.** Q1
  inspection opens the existing read-only `/show` projection for the proposed
  Brick and then asks whether its goal, information, and starting point are
  now understandable. A remaining explicit `no` opens UX-S34 with `vague` and
  the reason that existing context was insufficient; confirmation opens the
  existing vague reaction but records nothing. Exact `/show` projection fields
  follow DAT-051..054 and are not duplicated by Focus.
- **UX-141 [core] — Selection explanation is contextual evidence.** Q3 `yes`
  opens UX-F13 with the immutable FOC-049 facts. Its primary actions are
  `[c]ontinue · [b]ack · [?] I don't know`, avoiding a false yes/no question:
  continue reaches Q4, back restores Q2, and uncertainty uses UX-196
  `understand_subject`: it explains the structured draw fields once, restates
  whether they are sufficient, then continues, returns, or remains pending.
  The explanation may be folded, expanded, or paraphrased without changing its
  structured facts.
- **UX-142 [core] — Final Focus consent remains explicit.** FOC-048 Q4 renders
  UX-F14 with `Start focusing this Brick?` and
  `[y]es · [n]o · [?] I don't know`. `yes` invokes the original Focus accept
  transition immediately. `no` and uncertainty both open UX-S33 without
  recording a skip; their local answers remain distinct even though the
  recovery screen is the same. The symptom tree and final reaction own any
  later deferral evidence.
- **UX-143 [standard] — Assisted Focus cannot persuade or accept.** Skill or
  powered-up mode may summarize `/show`, paraphrase the exact FOC-049 facts, or
  mark one binary answer with concise attribution. It cannot add persuasive
  reasons, hide the positive-tail nature of the draw, claim the Brick is best,
  skip a question, start Focus, select a symptom, or commit a reaction. Dumb,
  powered-up, Skill, and later UI adapters preserve the same consent boundary.
- **UX-144 [core] — Feed has no classification toll.** Enter on UX-I02 commits
  exactly one Inbox Raw and does not open a route, Nature, Template, target,
  duplicate, or importance screen. The resulting revision revalidates the
  suspended proposal under UX-047. If no execution Work exists, ordinary
  `next` may immediately select the new Raw's useful triage opportunity.
- **UX-145 [core] — Raw triage starts with independent Work.** UX-T01 asks
  whether the Raw as it stands is something the user could work on by itself.
  `yes` enters complete Work materialization; `no` opens UX-T02; uncertainty
  follows one bounded behavioral tree and records no disposition. `skip`
  invokes FOC-051's typed triage deferral. No Raw is rendered as a Brick or
  assigned a `#` handle merely because it is being reviewed; it keeps the
  canonical `+` reference allocated when Feed created it.
- **UX-146 [core] — Destination pages separate browsing from creation.** UX-T02
  displays at most four core-ranked compatible existing checklists,
  RawShelves, and Bricks. `[m]ore matches...` advances through the same
  deterministic candidate set, `[s]earch...` opens typed autocomplete across
  the complete compatible set, and `[c]reate a new group...` opens UX-T03.
  No action asks the user to claim that every unseen destination is unsuitable.
  Because this screen owns `more`, its slash action reads `[/] menu...`.
- **UX-147 [core] — Destination consequences stay contextual.** Selecting a
  checklist asks whether to add a ListEntry; selecting a RawShelf asks whether
  to add membership; selecting a Brick uses UX-T04 to distinguish independent
  child Work from attached Raw context. The screen explains the selected
  target's consequence rather than asking the user to choose among Raw,
  ListEntry, and Brick ontology terms in one abstract form.
- **UX-148 [standard] — Assisted triage mirrors the dumb result.** Skill or
  powered-up mode may put one attributed disposition or FED-044-bounded
  recent-Raw batch proposal before UX-T01. It shows every affected Raw, target,
  entity kind, quantity operation, Nature, and Template that the proposal
  would settle. `no` enters unchanged dumb triage; `skip` defers only the Raw
  whose lottery opportunity opened the gateway. Assistance never treats recent
  temporal proximity as human confirmation.
- **UX-149 [core] — ListEntry duplicate actions expose quantity.** UX-T05
  shows owner, state, existing quantity, and newly fed quantity whenever an
  owner-scoped duplicate is suspected. An open entry offers keep, add the new
  amount, change quantity, and create a distinguishable separate item. A
  resolved or cancelled entry instead explains that reuse reopens the same
  identity while preserving its earlier history. The add row appears only for
  equal MOD-063 normalized units; a differing unit leaves keep, change, and
  distinguishable separation. No action silently increments, converts, or
  replaces a quantity.
- **UX-150 [core] — New-group discovery resolves existing kinds.** UX-T03
  uses `group` only as human-facing umbrella language and offers list, shelf,
  and independently suggestible Work behavior with one concrete explanation
  each. List continues to a finite-versus-living lifecycle question; shelf
  continues to RawShelf naming and preview; Work continues to ordinary Nature
  and structure discovery. No `Group` record, hidden fallback, or object is
  created merely by entering this screen.

## Status, history, and recovery

- **UX-025 [core] — Persistent stacked footer.** Every first-party guided
  surface presents one compact, deliberately subordinate footer below a dim
  horizontal divider. It always contains three two-line blocks in this order:
  subject location, temporal context, and dataset/session state. The first
  line of each block begins with `. `; its second line begins with two spaces.
  There are no emoji, product name, blank rows, or headings inside the footer.

  The location block shows the parent Brick or literal `<root>`, followed by
  the effective Domain path or literal `<no Domain>`. The time block shows the
  most useful truthful subject-specific temporal fact; when none exists it
  shows the operational workday. Its second line always shows the complete
  current civil date and local time as `Now`. The state block shows active
  Bricks, Raws awaiting review under `FED-011`, and unresolved typed review
  opportunities. These counts are not forecast eligibility: focusing,
  blocking, cooling down, or time-gating an active Brick does not remove it
  from the `bricks` count. A lazy review counts as soon as its claim is
  unresolved, including while its own cooldown temporarily excludes it from
  a draw. Its second line shows mode and current focus:

  ```text
  . #rs "Rock Splitter"
    Orbit › R&D › Rock Splitter
  . Last review: Sun, Aug 2, 22:14
            Now: Mon, Aug 3, 09:00
  . 18 bricks, 7 raws, 3 reviews
    mode: dumb, focus: idle
  ```

  A selected warning and concise subject-specific non-temporal facts render
  above this six-line footer rather than breaking its structure. The footer is
  persistent product chrome, not the main content or top header of an
  `InteractionEnvelope`.
- **UX-026 [core] — Discreet warning rotation.** If several warnings apply,
  one is selected replay-deterministically at a screen boundary. Rendering the
  same envelope does not rotate or consume randomness.
- **UX-027 [standard] — Recent action recap.** The main harness shows a short
  list of semantic user actions, grouping multiple domain events emitted by
  one command into one concise line.
- **UX-028 [standard] — Full history.** `/history` opens searchable, paginated
  semantic history and returns to the exact pending screen. CLI filters cover
  time, Brick/entity, scope, actor, semantic family, and relevance.
- **UX-151 [core] — Global search is always reachable.** `/search` is the one
  canonical global discovery command and is valid while any ordinary
  interaction is pending. `Ctrl-F` is the REPL accelerator for the same
  command; it is not a second semantic action. Opening search suspends the
  exact InteractionEnvelope, including any draft buffer, selection, cursor,
  and navigation checkpoints. Escape restores that envelope unchanged, while
  selecting a result opens read-only inspection and can return to the same
  result set and then to the suspended interaction. Global search covers
  Bricks, Raw, ListEntries, ExternalEntities, Domains, and RawShelves with
  visible result kinds and bounded deterministic pagination. It emits no
  domain event, consumes no draw, and never supplies a value to a pending
  typed selector unless that selector explicitly invoked its own contextual
  search. `/find` is not a core alias; an operator may interpret natural
  language such as "find" as `/search`. `/history` remains the separate route
  for semantic events rather than joining entity search.
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
- **UX-070 [core] — Capability-aware terminal styling.** The terminal
  renderer supports `auto | always | never`, with `auto` as the factory
  default. In `auto`, it emits no ANSI styling when output is not an
  interactive terminal, `TERM=dumb`, `NO_COLOR` is present, or required
  capabilities are unavailable. An explicit `always` or `never` is a
  presentation override only; it never changes an InteractionEnvelope or
  domain result.
- **UX-071 [standard] — Theme-owned ANSI palette.** The factory renderer uses
  terminal-defined ANSI palette entries and intensity attributes rather than
  fixed RGB values or a guessed light/dark theme. Shortcut brackets and
  dividers are dim; the shortcut character is bold cyan; ordinary labels
  retain the terminal's default foreground; success, warning, and error roles
  use bold green, yellow, and red respectively. The entire persistent footer,
  including its dots and divider, uses the terminal's default foreground at
  dim intensity and never an accent color. Only semantic values use normal
  intensity: the parent title text but not its handle or quotation marks,
  each Domain segment but not `›`, the primary temporal value but not its
  label or the complete `Now` line, each count numeral, and the `mode` and
  `focus` values but not their labels or punctuation. These values are neither
  bold nor assigned a fixed ANSI color. Style resets are scoped so one
  component cannot leak into another. Little Ant 1.0 does not query terminal
  background color or infer a theme.
- **UX-072 [core] — Selection and color-independent meaning.** Arrow-key
  selection in the command palette uses reverse video. Selection also has a
  non-style cursor indication in every rendering under UX-255. Color and
  intensity may reinforce but never exclusively communicate selection, action,
  warning, state, or validity.
- **UX-073 [core] — Display-cell alignment.** ANSI control sequences have zero
  display width. Padding, columns, clipping, and wrapping use rendered Unicode
  display cells rather than bytes, code points, or styled-string length.
  Emoji and wide-character measurement uses the terminal renderer's declared
  width policy, with a safe inline fallback when exact alignment cannot be
  guaranteed.

## Dumb and powered-up harness

- **UX-033 [core] — Dumb completeness.** The dumb REPL invokes the same
  canonical CLI/protocol pipeline and can complete every required flow without
  AI. One-key input, cursor movement, ANSI capability detection, layout, and
  selection highlighting belong to the terminal harness; valid actions,
  transitions, deterministic draws, validation, undo eligibility, and domain
  events belong to the dispatcher and core.
- **UX-034 [standard] — Explicit powered-up adapter.** A working invocation is
  `lant --power-up <executable>`. The executable receives prompts only on
  stdin.
- **UX-035 [standard] — Startup handshake.** Before entering the REPL, the host
  sends a bounded versioned structured challenge, enforces execution and parse
  limits, and fails startup if the adapter does not return exactly one valid
  response.
- **UX-036 [standard] — Bounded extraction.** Cheap-model framing text may be
  removed only through a deterministic bounded object extractor. Multiple,
  ambiguous, malformed, or unsupported objects fail rather than being guessed.
- **UX-037 [standard] — Visible mode.** The footer always displays `mode: dumb` or
  `mode: powered up · by: <executable>`.
- **UX-038 [standard] — Limited assistance.** Powered-up mode may translate,
  classify, rank bounded candidates, suggest patterns, and contribute
  attributed provisional comparisons. It cannot create canonical events,
  human evidence, external approval, merge, or completion directly.
- **UX-039 [standard] — Skill equivalence.** The operator skill may interpret
  unrestricted natural language more deeply. By default it renders the same
  pending question, options, order, shortcuts, and action IDs as the dumb
  REPL. Only a flow that explicitly declares an assisted proposal gateway
  under `UX-060` may precede its dumb entry with one canonical proposal.
  Contextual personality microcopy may vary only under `UX-064..065`. The
  Skill calls the canonical CLI/protocol directly and never automates, scrapes,
  or treats the REPL as domain authority.
- **UX-043 [core] — Powered-up is a measured delta.** A powered-up simulation
  starts from the same state, clock, configuration, and random stream as the
  accepted dumb flow. It normally renders the same question and complete
  option set, with optional assistance under `UX-059` and bounded personality
  paraphrase under `UX-065`. A declared `UX-060` gateway may instead offer one
  complete canonical result before that flow. Powered-up mode never becomes
  the source of screen grammar.
- **UX-044 [core] — Downstream mirror order.** Skill and local-web renderings
  are derived only after the corresponding dumb and, when applicable,
  powered-up REPL paths are defined. A future mobile surface follows the same
  conformance order. A downstream convenience may motivate a later
  REPL-contract revision, but cannot silently fork the product language.
- **UX-045 [core] — Footer context block.** Parentage and Domain path occupy
  the first two footer lines. Missing values render explicitly as `<root>` and
  `<no Domain>` so the footer never shifts shape. At most one selected warning
  plus its overflow count and concise subject-specific facts may appear above
  the footer. Technical selection provenance is available through contextual
  `?`; it is not shown by default. Rendered Domain paths use `›` between
  hierarchical segments.
- **UX-046 [core] — Automatic opening opportunity.** Starting or restoring the
  REPL never lands on an idle command prompt. It first restores an exact
  pending interaction or otherwise invokes the canonical `next` pipeline and
  displays its useful proposal. `next` itself may return a valid current-focus
  continuation. The no-eligible case displays the canonical useful empty
  state. The visible heading names the semantic opportunity or state, not the
  command that selected it: an ordinary focus proposal therefore says `Work:`,
  never `Next:`.
- **UX-047 [core] — Secondary command escape.** A proposal screen places only
  `[/] more...` below its primary actions and immediately above the divider.
  Direct completion and Feed are contextual palette commands rather than
  persistent proposal actions. `/feed` opens the Feed input screen; there is
  no default Feed prompt. Escape from uncommitted input restores the exact
  proposal without a draw or event. A confirmed Feed changes the domain
  revision, so the old proposal is revalidated and, when stale, recomputed
  instead of being applied blindly. A pristine first start remains the
  deliberate exception: it displays `[f]eed` directly because feeding the
  first Raw material is its primary useful action.
- **UX-048 [core] — Next action grid.** The reference `next` screen renders
  the primary Focus answers on the first row and the secondary command escape
  on the second, using stable whitespace-aligned columns rather than
  middle-dot separators:

  ```text
  [y]es    [s]kip    [?] I don't know
  [/] more...
  ```

  Narrow renderers may wrap whole actions while preserving row membership and
  canonical action order.
- **UX-049 [standard] — Dumb free-text language hint.** Every dumb-mode screen
  that accepts free text displays `Tip: prefer English for consistent titles
  and search.` discreetly beside or immediately above that input. The hint is
  not repeated on single-key choice screens, where the user cannot write
  content. This is advice, not validation: any language remains accepted and
  the original input is preserved under `PRD-012`. An input known to accept
  only Brick titles uses the more precise `Tip: write Brick titles in
  English.` instead.
- **UX-050 [core] — Nature before Template.** Dumb Raw-to-Work materialization
  resolves one Nature through UX-K01, or through UX-K02 followed by UX-K03,
  before optionally offering compatible Templates.
  Nature and Template never share one flat choice screen.
- **UX-051 [core] — Assisted proposal consent.** Skill or powered-up mode may
  use the `UX-060` gateway to propose a Template that visibly resolves one
  Nature. The proposal requires `[y]es · [n]o · [?]`; `no` returns to the
  unchanged dumb flow without accepting proposal evidence.
- **UX-052 [core] — Example-backed Nature choice.** The direct factory Nature
  choice presents one Nature per line with one short, concrete example.
  Text surfaces align the examples as a visually quieter second column; other
  surfaces preserve the same one-to-one association. Examples explain
  behavior only: they are not classification evidence, title suggestions,
  Template selections, or domain-specific branches.
- **UX-053 [core] — Template-choice defaults.** UX-K05 lists compatible
  Templates only after dumb Work materialization has resolved one Nature.
  Dumb mode marks no Template and not even `no template` with `*`; the human
  must make an explicit choice. Skill or powered-up mode may mark one
  compatible Template as an attributed suggestion, but cannot mark an
  unattributed or ambiguous default. Rejecting or bypassing a Template
  preserves the resolved Nature.
- **UX-054 [core] — Structured dumb scheduling.** Dumb mode configures cadence
  through bounded schedule-shape, preset, positive-integer, calendar-anchor,
  and time-unit choices. It never asks the core to interpret natural-language
  frequency text. Skill or powered-up mode may translate phrases such as
  `twice a month` into the same canonical structure, but must show the
  attributed structured result before acceptance.
- **UX-055 [core] — Civil clock, explicit operational date.** The footer always
  renders the real civil date and local clock. When the current workday label
  differs from the civil date, it also renders `workday: <date>` explicitly.
  A served habit whose nominal habit day differs identifies that nominal slot
  and its exact closing instant in subject-specific context. No surface may
  replace a civil date with an operational label or make a flight,
  appointment, or timed deadline appear to occur on another date. UX-R01 is
  the canonical differing-day rendering.
- **UX-056 [core] — Dense Template choice before categories.** A Template
  choice lists all compatible options together while they fit the bounded
  surface and each visible option can receive a unique in-word shortcut.
  Shortcut characters never repeat within one screen. Only when that contract
  cannot be satisfied does the interaction introduce stable navigational
  categories or pagination. UX-K06 fixes the dense scheduled-commitment
  boundary example. Categories organize discovery; they never change
  Nature, Template semantics, ranking evidence, or runtime behavior.
- **UX-057 [core] — Atomic break preview.** Breaking an `atomic_task` previews
  the proposed destination Nature, the retained parent, every new part and its
  Nature, the initial local order, provenance, and lazy-review markers before
  confirmation. UX-088 states the structural consequence in human terms
  rather than leading with internal ontology. `yes` commits the Nature change and
  structure together; `no`, uncertainty, or Escape follow their ordinary
  confirmation and navigation semantics without creating partial structure.
  Entry may be explicit `/break` or a provisional symptom reaction; the final
  preview remains the single mutation boundary in either case. `yes` creates
  the complete provisional order under IMP-030 without first interrupting the
  transaction for human comparisons.
- **UX-058 [core] — Provisional skip navigation.** The served-work symptom
  screen and its symptom-specific reaction screen are uncommitted navigation
  checkpoints. A symptom shortcut opens the matching reaction screen without
  recording evidence. Only a final reaction action commits the symptom and
  reaction under `WRK-047`; `skip anyway` is the explicit defer-only action.
- **UX-059 [core] — Assistance decorates one canonical choice.** Skill and
  powered-up mode may mark at most one existing action with `*` and place one
  concise attributed natural-language note immediately below the unchanged
  option set when the current flow is not being preceded by a `UX-060`
  proposal. The note may explain evidence, distinguish choices, suggest an
  action, or offer a tip. It cannot add an action, hide one, alter its meaning,
  answer automatically, or claim certainty unsupported by evidence. Without a
  defensible suggestion, neither `*` nor a persuasive note appears.
- **UX-060 [core] — Declared assisted proposal gateway.** A specific flow may
  declare that Skill or powered-up mode can precede its dumb entry with one
  attributed confirmation of a complete canonical result reachable through
  that unchanged dumb flow. The preview exposes every consequential resolved
  value and uses `[y]es · [n]o · [?]`. `yes` applies the same canonical
  validation and domain transition as the dumb route. `no` accepts no proposal
  evidence and enters the dumb flow at its original first question with input
  and navigation checkpoint preserved. `?` explains the proposal and restores
  the same confirmation. A gateway is unavailable by default and cannot add a
  result, action, or semantic shortcut that the dumb path cannot express.
- **UX-061 [core] — Clarification begins with human orientation.** The
  `vague` reaction `clarify now` does not declare a `UX-060` gateway. Dumb,
  powered-up, and Skill modes first show the same canonical question asking
  which aspect is unclear. Assistance may decorate that choice under `UX-059`,
  but it cannot propose desired result, completion criteria, next action, and
  scope before the human identifies the uncertainty.
- **UX-062 [core] — Unbound finite-choice key.** Only shortcuts visibly bound
  by the pending finite-choice screen are valid. An unbound key is never a
  hidden alias and is not ignored silently. The surface gives one concise,
  educational recovery and restores the same interaction. On `Focus?`,
  pressing `n` says `[n] is not available here. To decline this suggestion,
  use [s]kip.` It records no event, changes no revision, consumes no draw,
  and applies no cooldown.
- **UX-063 [core] — Current-focus resting screen.** Accepting `Focus?`
  immediately starts or resumes the Brick and enters a stable current-focus
  screen. It asks no new question, invokes no draw, and exposes the ordered
  action strip `[d]one · [s]kip · [/] more...`. `done` comes first because
  completion is the positive ordinary outcome of active focus. `skip` opens
  the served-work symptom screen for the focused Brick; pressing it alone
  records no skip evidence, cooldown, or lifecycle change. The Little Ant
  footer state block identifies the focused Brick. The immediate
  `focus_started`
  result may carry
  UX-064 microcopy. Restarting or restoring the REPL later resumes a sober
  rendering of this screen while that focus remains valid; it neither repeats
  the transition message nor asks whether the focus is stale before the
  configured stale-focus boundary.
- **UX-064 [standard] — Contextual personality catalog.** Decorative
  personality microcopy appears only after a transition where warmth or light
  humor helps; it never appears on the opening `Focus?` screen, where it would
  compete with the decision. The closed 1.0 intent catalog is:

  ```text
  focus_started | work_completed | skip_acknowledged | safe_end
  ```

  The factory English catalog contains exactly 16 phrases for each intent.
  Phrase selection is replay-deterministic, remains stable for the same
  transition-result interaction, appears only there, and is isolated from
  forecast randomness. A later continuation does not replay or reselect it.
  Microcopy is never a domain event or evidence. Errors, warnings,
  external-effect approvals, evidence questions, and active decision screens
  remain canonical and sober. No phrase may shame, manipulate, invent facts,
  imply a hidden action, or discourage the user from reporting an obstacle.
- **UX-065 [standard] — Assisted personality paraphrase.** Powered-up mode or
  the Skill may paraphrase the selected dumb phrase once per interaction in
  one or two English lines. It retains the selected intent and factory phrase
  identity, stays stable when the screen is redrawn, and cannot alter the
  subject, question, actions, ordering, shortcut, status, or semantic result.
  The paraphrase adds no factual claim, deadline, advice, guilt, or pressure.
  This bounded personality text is the only ordinary wording variation allowed
  between otherwise equivalent dumb, powered-up, and Skill screens.
- **UX-066 [core] — Next does not preempt focus.** `/next` is a contextual
  current-focus palette command. Invoking it creates a new pending Focus
  proposal while the current focus remains visible in status and unchanged in
  state. Only accepting the new proposal switches focus under `FOC-033`.
  Escape and any proposal outcome that does not accept another Brick return to
  the prior current-focus screen.
- **UX-067 [core] — Pause is explicit and non-propositional.** `/pause` is a
  contextual current-focus palette command implementing `WRK-048`. It commits
  immediately, returns a sober result identifying the still-WIP Brick, and
  leaves focus idle. It does not ask the user to resume immediately, invoke
  `next`, or emit personality microcopy.
- **UX-068 [core] — Symptom shortcuts favor common meaning.** On the
  served-work symptom screen, the human-facing obstacle family owns its
  natural and more frequently useful initial as `[b]locked or waiting`;
  `bored` therefore uses the visible in-word shortcut `bo[r]ed`. The next
  screen classifies that family without asking the human to distinguish
  internal `Dependency`, `Wait`, time, or Place terminology. The relative,
  present-tense importance symptom is `[l]ess important`; it does not
  introduce a `priority` field or permanently reclassify the Brick. `[d]one`
  remains reserved for completion. Stale intent or content uses the visible
  in-word shortcut `o[u]t of date`, leaving `[o]ther` unchanged. The same
  bindings apply on every surface that renders this symptom namespace.
- **UX-069 [core] — Current-focus done has no confirmation toll.** Pressing
  `[d]one` on the current-focus screen commits `WRK-049` immediately and
  renders one `work_completed` result. That transition may use the
  deterministic UX-064 personality catalog. The result waits with
  `[n]ext · [/] more...`; it does not consume another draw automatically.
  Pressing `n` invokes the same canonical pipeline as `/next`, and `/undo`
  remains available through the contextual palette. Because completion closes
  the prior provisional flow, `Left Arrow` on this result cannot navigate back
  into its Focus screen; instead it offers the UX-019 undo preview for that
  typed completion. The surface does not ask the user to confirm work they
  have just declared complete.
- **UX-265 [standard] — External consent shows the outside-world consequence.**
  UX-A01 is the shared approval grammar for every DAT-068 purpose. Its heading
  is a plain consequence question—send, delete, create, update, or cancel—and
  its body names the exact provider account, target, payload summary, and
  irreversibility. `[y]es` approves only the displayed effect revision;
  `[e]dit` appears only for editable payloads; `[n]o` rejects it; `[l]ater`
  appears only when a pending effect can remain meaningful. Lottery-selected
  approvals alone retain typed `[s]kip`. Cleanup batches additionally expose
  `[i]nspect items` before consent. No Pack key, variable-like purpose, UUID,
  or idempotency token appears in the primary screen.
- **UX-266 [standard] — Effect recovery never encourages blind repetition.**
  UX-EFX00 renders succeeded, retryable failure, terminal failure, or unknown
  outcome from DAT-070 as different states. Success names the observed
  provider receipt in ordinary language. Retryable failure offers safe retry
  only when DAT-071 permits it. Unknown outcome leads with read-only provider
  checking when available; otherwise it requires explicit external
  verification or a new duplicate-risk approval. Stop leaves inspectable
  history and never relabels the effect as success. Powered-up and Skill may
  explain an error or mark a safe recovery, but cannot retry, verify, approve,
  or invent a provider result.
- **UX-267 [standard] — Import is a short, Raw-first dumb flow.** UX-IMP00 uses
  a searchable source selector, then only the modes declared by its catalog
  row. An installed online source without a configured account first opens
  UX-IMP00's separate connection preview; accepting it connects only and
  returns to the still-unapproved import intention. UX-IMP01 is the complete read-only preflight. The only committing
  action is `[i]mport`; it has no Enter default. UX-IMP02 reports verified Raw
  counts and offers ordinary triage or next. Cleanup appears only after a
  verified supported migration and uses UX-A01 as a separate consent. Imported
  task-shaped content may offer one attributed or preset bulk-adoption
  preview, but rejection returns to unchanged Raws and mixed notes never get a
  Work default.
- **UX-268 [standard] — Calendar adoption and reconciliation use visible
  scope.** UX-CAL00 distinguishes this occurrence, whole series, all-day civil
  Work, and preserve as Raw before any Work creation. UX-CAL01 shows local and
  observed source values side by side and asks what to keep locally. Missing
  or cancelled source data offers cancel local, keep and detach, or separately
  recreate; none is selected by default and none implies attendance. Any
  remote mutation then uses UX-A01. Assisted modes may propose one route with
  attribution, but rejection restores the identical dumb choices.
- **UX-269 [standard] — The shipped web surface is local and subordinate.**
  `/web` starts DAT-075's loopback host, renders the access URL and expiration,
  and opens no browser unless the presentation host is explicitly allowed to
  do so. The browser receives canonical envelopes with the same visible action
  labels and revision checks. Closing the host invalidates its session token;
  reconnecting revalidates current state instead of replaying a browser action.
  The UIAdapter cannot unlock the vault, retain provider credentials, or
  create a second command grammar.
- **UX-270 [standard] — Pack installation requires two independent
  understandings.** UX-PACK00 first establishes signer trust, then separately
  previews installation. A verified official or already trusted publisher
  skips only the trust question, never the Pack preview. The preview names
  display name, publisher/trust class, version, exact digest abbreviation,
  every component kind, HTTP hosts, credentials, effect purposes, and local
  UI authority in human language. It has no default or Enter acceptance.
  Trusting a new community key shows its full fingerprint and returns to the
  still-unapproved Pack preview. Trust and install use UX-196
  `binary_consent` independently.
- **UX-271 [standard] — Updates show semantic and permission difference.**
  UX-PACK01 compares installed and candidate version/digest, components,
  permissions, configuration, and every binding that would remain old, be
  rebound, or become unavailable. `[u]pdate` accepts only that complete plan;
  `[k]eep current` changes nothing. An update with no visible difference still
  requires the same approval. Powered-up and Skill may summarize or flag risk,
  but cannot trust a key, install, update, rebind, remove, refresh, or collect
  archives. Update uses UX-196 `binary_consent`; inspect changes is its bounded
  evidence view.
- **UX-272 [standard] — Revocation is a sober unavailable state.** UX-PACK02
  names the Pack, signer/digest, affected components and bindings, catalog
  sequence, and plain recovery choices. It never offers run anyway, ignore,
  downgrade to another revoked digest, or delete canonical data. Replacement,
  pause, manual fallback, and inspection reuse existing binding flows. A stale
  official catalog warns on the Pack manager and blocks only new official
  installation/update. Its uncertainty route is UX-196 `reaction_choice`.
- **UX-273 [core] — Migration begins with evidence, not a promise.** UX-MIG00
  is the dumb `/migrate` entry and the visual form of `MIG-035`. It shows the
  exact source and target, verified event/object counts, the four mapping
  classes, and three consequential truths: old before/after evidence is not
  importance, old effects will not run, and neither source nor target has been
  changed. Build is available only with zero blockers and has no default.
  Inspecting or repairing returns to a newly hashed preflight report.
- **UX-274 [core] — Candidate and cutover are separate consent boundaries.**
  UX-MIG01 appears only after a full valid candidate replay and says explicitly
  that the target remains unchanged. UX-MIG02 then previews the exact atomic
  switch and retained backup. Neither screen has a selected row, Enter
  behavior, `yes` shorthand, or assisted acceptance. Leaving either screen
  preserves the candidate for later inspection; discarding it is a separate
  previewed local operation.
- **UX-275 [core] — Assistance cannot make migration less inspectable.** Skill
  or powered-up mode may summarize why a mapping is provisional, rank the
  finite repair choices, or mark one non-committing inspect action. It may not
  omit a mapping class, convert a warning into a judgment, alter the source,
  allocate identities, build, cut over, roll back, discard, or start provider
  cleanup. Rejecting an assisted repair suggestion restores the exact dumb
  blocker screen and plan revision.
- **UX-276 [standard] — Place stays lightweight in the UI.** UX-PL00 is the
  only dumb PlaceCondition builder. The blocked-or-waiting route enters with
  `required` already explained by the sentence “You said you cannot continue
  until you are there”; direct Context maintenance first chooses required or
  preferred. Input is one English place label with suggestions from labels
  already used in the dataset. The preview exposes the kind and consequence;
  it never asks for a Place object, global identity, hierarchy, coordinates,
  or geofence.
- **UX-277 [standard] — Place confirmation preserves the selected Work.**
  UX-PL01 leads with the complete selected Brick and required label, then asks
  `Are you there now?` with `[y]es · [n]o · [?] I don't know`. Yes continues
  to the exact pending `Focus?`; no performs WRK-159's local deferral and draws
  nothing until the next canonical `next` request. The screen has no default.
  Powered-up and Skill may explain the condition or mark a current trusted
  adapter observation, but cannot infer location, answer, or bypass consent.

## Errors and dry-run

- **UX-040 [core] — Typed educational errors.** Failures include stable codes
  for at least precondition, not found, and ambiguous reference, plus safe
  concrete recovery actions when available.
- **UX-041 [core] — Global dry-run.** Every catalogued CLI operation accepts
  `--dry-run`. A mutating operation performs ordinary parsing, resolution,
  validation, tick, and deterministic calculation without events,
  checkpoints, persistent randomness, or external effects. A read-only
  operation returns its ordinary validated projection with the dry-run fact
  visible and neither gains authority nor fails merely because the option is
  redundant.
- **UX-042 [core] — Useful failure ending.** An error leaves the user with a
  concrete correction, bounded search, valid alternative, or explicit safe
  stop; never an unexplained dead end.

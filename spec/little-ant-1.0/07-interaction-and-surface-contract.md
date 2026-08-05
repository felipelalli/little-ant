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
- **UX-002 [core] — Almost-literal parity.** REPL, first-party web/mobile,
  UIAdapters, and operator skill preserve the same wording, punctuation,
  subject order, action order, shortcut letters, emojis, defaults, and screen
  transitions.
- **UX-003 [core] — Permitted adaptation.** A surface may change wrapping,
  density, pagination, physical control, and accessibility representation.
  It may not rename, reorder, omit, combine, or reinterpret canonical actions.
- **UX-004 [core] — Dumb REPL reference composition.** The first-party dumb
  REPL is the reference layout and complete guided-flow harness. A screen and
  transition are approved there before powered-up automation, skill, web, or
  mobile presentation may claim parity. Other surfaces render the same
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
  command shortcuts never steal typed text.

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
  routes. Remaining cross-screen shortcut preferences and collisions stay
  under `OPEN-UX-001`.

- **UX-015 [core] — Suggested default.** `*` marks at most one defensible
  suggested action. On a finite choice with a visible default, pressing either
  literal `*` or Enter immediately selects that same action. The two keys are
  aliases for the displayed default, not separate semantic actions. Without a
  visible `*`, Enter does not guess and literal `*` is unbound. Input screens
  keep their editor grammar: `*` inserts text and Enter submits or advances as
  declared by UX-011. No evidence means no default unless the screen contract
  defines an explicit factory default, as UX-O02 does.
- **UX-016 [core] — Contextual uncertainty.** `[?] I don't know` is visible in
  every finite decision. It opens a nested assistance interaction without
  itself recording an answer or skip. Escape restores the same pending
  envelope. Assistance may produce an explicitly confirmed proposal or
  restart a bounded decision aid when that screen's grammar declares it; it
  never silently answers the decision.
- **UX-017 [core] — Nested system help.** Within contextual assistance, another
  `?` opens Little Ant help. Generic help never silently answers the decision.
- **UX-018 [core] — Contextual later.** `[l]ater` exists only for honestly
  deferrable proposals and opens an explicit date choice before recording
  anything.

Final shortcut collisions, layout variants, assistance labels, and accessible
no-emoji rendering remain `OPEN-UX-001`.

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
- **UX-022 [core] — More palette.** The canonical `[/] more...` action opens a
  searchable input palette containing only commands and secondary actions
  valid in the current state. Before any query, it shows a small,
  deterministically ordered contextual set. Typing filters the complete valid
  set; descriptions make any implicit current subject explicit. Arrow keys
  select, Enter runs, and Escape restores the exact pending interaction
  without an event or another draw. A read-only command returns to that
  interaction. A mutating command resolves it or revalidates it against the
  new revision. The palette guides required arguments. In ordinary input mode,
  `/` remains literal text.
- **UX-023 [core] — Grammar inspection.** `la grammar`,
  `la grammar --screen <grammar>`, and `la grammar --json` expose the same
  versioned registry used by all surfaces. The current envelope remains the
  authority for state-valid actions.
- **UX-024 [core] — Command transparency.** A confirmed guided action can show
  the exact canonical CLI command and canonical human result, teaching one
  scriptable language without exposing transport flags.
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
  reference-capable input opens Brick autocomplete; typing `@` opens
  person-or-company autocomplete. Search matches the canonical handle and
  title or name. Results always use the complete typed rendering from MOD-010.
  `New Brick...` or `New person or company...` appears only when creation is a
  valid action in the suspended interaction. Selecting a result returns its
  UUID-backed reference; the user never has to memorize or type an internal
  UUID. Handle search and creation do not make lookalike literal text into a
  semantic annotation without confirmation.
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
  streaks. Text or symbols preserve the distinction without relying on color;
  the exact compact rendering remains under `OPEN-UX-001`.
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
  parent, states `All <count> tracked parts are done.`, and asks `What should
  happen?`. Its visible actions are `[d]one · [a]dd more work` followed by
  `[s]kip · [?] I don't know`, then `[/] more...`. `Last child done` is the
  primary temporal footer fact. Actions follow `WRK-066`; uncertainty and
  Escape preserve the pending review. The screen has no Nature label,
  project-only wording, completion inference, or decorative personality line.
- **UX-084 [core] — Big-recovery grammar.** Selecting `bi[g]` on the served-work
  symptom screen opens a provisional reaction on the same Brick. It asks
  `What would help?` and exposes `[b]reak it into parts`, `[c]ollect more
  context`, `[l]earn about the subject`, `[s]kip anyway`, `[?] I don't know`,
  and `[/] more...`, in that order and without a default. Actions follow
  `WRK-067`. Escape, empty-buffer Backspace, or Left Arrow restores the exact
  symptom screen without evidence or mutation. The screen has no technical
  Nature explanation or decorative personality line.
- **UX-085 [core] — Dumb part collection.** Choosing `break` opens one pending
  editor headed `Break into parts:`. It identifies the retained Brick, lists
  every drafted part in entry order, and keeps the next numbered `›` input
  active. Enter on non-empty text adds that draft and immediately opens the
  next line. Once at least two parts exist, Enter on an empty input advances
  to UX-B01; before then it cannot produce a decomposed preview. The input
  displays the discreet title-specific hint `Tip: write Brick titles in
  English.` under UX-049. Escape, Left Arrow, or Backspace on an already empty
  input restores the preceding pending-part checkpoint. No title, handle,
  Nature, comparison, child, symptom, or history is durable during collection.
- **UX-086 [standard] — Assisted decomposition draft.** When title,
  Description Raw, linked material, or related-Brick evidence supports a
  concrete decomposition, powered-up mode or the Skill may precede UX-085
  with one English-language draft containing every suggested part and a
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
  confirmation for decomposition. It identifies the retained Brick, states
  naturally its resolved destination Nature (`project` in the reference
  composition) and that its parts replace it as suggested Work, lists pending
  parts without not-yet-durable handles, and
  groups the deterministic `atomic_task` and entered-order lazy-review
  defaults. It asks `Apply this change?` and exposes `[y]es`, `[e]dit`, `[n]o`,
  `[?] I don't know`, and `[/] more...`, without a default. `yes` performs the
  one atomic mutation; `edit` restores UX-B00 with every draft; `no` discards
  the drafts, cancels decomposition, and restores its origin without evidence;
  uncertainty explains Nature, order, and provenance before returning.
  Reverse navigation follows UX-019 and preserves the drafts. An assisted
  preview adds only explicit exceptions to the dumb baseline and marks every
  proposed Nature, initial-order, or Dependency claim `AI-suggested · review
  later`. Accepting the whole preview does not erase that provenance. When
  entry came from `big`, `yes` also records that symptom and recovery; direct
  `/break` never fabricates them.
- **UX-089 [core] — Committed-break result.** After UX-B01 `yes`, UX-B02 states
  `Broken into <count> parts:`, renders the retained parent and newly durable
  children with their allocated handles, explains that children may now
  appear as Work and that the parent returns only for scope review, and offers
  `[n]ext` followed by `[/] more...`. It performs no automatic forecast draw,
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
  personality copy, or explanatory heading; contextual `?` can explain the
  changed comparator. Skipping that replacement commits the low-confidence
  placement from IMP-009. In explicit `/order`, the next unresolved pair
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
  the three affected siblings the user would choose if only one could be done
  now. It has no default, model answer, or hidden impact calculation. Selecting
  one records two direct current judgments placing that winner above each
  other Brick, retires only incompatible current edges, preserves an applicable
  coherent relation between the two non-winners, and resumes the interrupted
  cadence. The visible shortcuts are stable unique characters from the three
  displayed choices under UX-013. A second uncertainty response and minimal
  cycles longer than three remain under `OPEN-IMP-002` rather than being
  guessed by the dumb host.
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
  non-style cursor indication in monochrome rendering, whose exact accessible
  marker remains under `OPEN-UX-001`. Color and intensity may reinforce but
  never exclusively communicate selection, action, warning, state, or
  validity.
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
  `la repl --power-up <executable>`. The executable receives prompts only on
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
- **UX-044 [core] — Downstream mirror order.** Skill and web/mobile renderings
  are reviewed only after the corresponding dumb and, when applicable,
  powered-up REPL paths are accepted. A downstream convenience may motivate a
  later REPL-contract revision, but cannot silently fork the product language.
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
  first Brick is its primary useful action.
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
- **UX-050 [core] — Nature before Template.** Dumb Feed resolves one Nature
  through UX-K01, or through UX-K02 followed by UX-K03, before optionally
  offering compatible Templates.
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
  Templates only after dumb Feed has resolved one Nature. Dumb mode marks no
  Template and not even `no template` with `*`; the human must make an explicit
  choice. Skill or powered-up mode may mark one compatible Template as an
  attributed suggestion, but cannot mark an unattributed or ambiguous
  default. Rejecting or bypassing a Template preserves the resolved Nature.
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
  appointment, or timed deadline appear to occur on another date.
- **UX-056 [core] — Dense Template choice before categories.** A Template
  choice lists all compatible options together while they fit the bounded
  surface and each visible option can receive a unique in-word shortcut.
  Shortcut characters never repeat within one screen. Only when that contract
  cannot be satisfied does the interaction introduce stable navigational
  categories or pagination. Categories organize discovery; they never change
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
  state block identifies the focused Brick. The immediate `focus_started`
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
  remains reserved for completion. The same bindings apply on every surface
  that renders this symptom namespace.
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

# 6. Work, time, and adaptation

## Focus, WIP, and completion

- **WRK-001 [core] — One focus, several WIPs.** Human focus points to zero or
  one Brick globally. Several Bricks may remain `wip`; focusing another Brick
  removes attention from the previous one but leaves it WIP.
- **WRK-002 [core] — Focus starts WIP.** Accepting focus on an idle Brick
  atomically makes it WIP and current. Focus changes are event history. The
  guided surface then rests on the current focus without another draw or an
  immediate completion question.
- **WRK-003 [calibration] — Soft WIP limit.** The factory soft limit is three.
  Additional WIPs are allowed and increase review pressure.
- **WRK-004 [core] — No silent clearing.** A stale current focus remains the
  current continuation and asks for an explicit check-in under `UX-080`; it
  does not enter the lottery. A WIP Brick that is no longer current may create
  a separate review opportunity to resume, return to idle, complete, archive,
  or supersede. Nothing is silently completed or cleared, and neither path
  fabricates observed work duration.
- **WRK-005 [core] — Done is direct.** A served Brick can be completed without
  first starting it through the contextual `/done` command. Completion
  without a prior start is ordinary `done` with unknown observed duration,
  not `already done` or a synthetic zero-length run. Direct completion remains
  available without competing visually with Focus and skip.
- **WRK-006 [core] — Lifecycle distinctions.** `done`, `archived`, and
  `superseded` preserve different outcomes and lineage. Stopping an execution,
  missing a habit opportunity, and abandoning an external delegation are
  context-specific outcomes, not one generic `abandon` command.
- **WRK-048 [core] — Pause clears attention, not work.** Pausing closes the
  current focus interval and clears the global focus pointer while leaving the
  Brick WIP. It preserves the active Domain and importance evidence, records
  no skip symptom, applies no cooldown, and performs no new draw. `paused` is
  an action and historical fact, not another Brick lifecycle state.
- **WRK-049 [core] — Focused completion is immediate and reversible.**
  Pressing `[d]one` on the current-focus screen atomically closes the current
  focus interval, completes the focused Brick, and clears the focus pointer.
  It does not interpose a confirmation screen. The typed completion event is
  eligible for semantic undo under `UX-020`; undo restores the prior Brick and
  focus state when its recorded preconditions still hold.

## Skip as evidence

- **WRK-007 [core] — Symptom before reaction.** Served-work skip first asks
  what prevented focus, then opens a separate reaction decision. Choosing a
  symptom is provisional navigation, not yet a recorded skip or remediation.
  The visible `blocked or waiting` family first opens a human-oriented
  classification question; it never forces the user to know the core's
  `Dependency`, `Wait`, time, or Place distinctions.
- **WRK-008 [core] — Canonical symptom family.**

  ```text
  vague | hard | big | blocked_or_waiting | tired | bored | fear
  | less_important | out_of_date | other
  ```

  `blocked_or_waiting` is the visible and explicitly unclassified obstacle
  evidence. A completed classification records the more precise `blocked` or
  `waiting` evidence instead. The core never guesses one from the other.
  `meh`, `kill`, `alternatives`, and `change subject` are not symptoms.

- **WRK-009 [core] — Waiting versus blocked.** `waiting` means an unresolved
  external person, event, or condition with no known action. `blocked` means a
  missing actionable prerequisite such as a Brick, information, access, or
  material. The classification asks what must happen before work can continue:
  another task produces `blocked` evidence plus a `Dependency`; someone who
  must respond produces `waiting` evidence plus a `Wait` linked to an
  `ExternalEntity` of any eligible kind; an external event or condition
  produces `waiting` evidence plus a `Wait`; a date or time produces `waiting`
  evidence plus `not_before`, not a `Wait`; and a location produces `waiting`
  evidence plus a Place condition, not a `Wait`. Deferring before
  classification records `blocked_or_waiting` explicitly rather than
  fabricating precision.
- **WRK-050 [core] — Declared request handoff.** When the required request has
  already been made, confirming the route activates its Wait after the pending
  review policy is resolved. When it has not been made, the accepted preview
  creates an enabling Brick and declares a successor Wait for the same
  affected Brick and response target. Completing that enabling Brick
  atomically resolves its Dependency and activates the Wait; the affected
  Brick is never transiently released into the forecast between those states.
- **WRK-051 [core] — Wait review policy.** Every active Wait stores one
  `review_not_before` instant. It means "do not offer another review before
  this time," not a fixed appointment, deadline, or overdue boundary. For a
  human-response Wait with no stronger evidence, the factory dumb screen
  suggests three days and also offers tomorrow, one week, and a guided custom
  instant; every relative choice displays its absolute date. `wait longer`
  reuses the same screen. Under a fixed versioned policy, sufficient attributed
  response history for the same ExternalEntity may move the suggestion to one
  existing option; powered-up or Skill assistance may do the same with visible
  provenance. Neither invents a hidden duration or silently changes policy.
- **WRK-052 [core] — Wait review outcomes.** Once `review_not_before` opens and
  the review is selected, it offers the canonical outcome families `response
  received`, `wait longer`, `follow up`, `change what is blocking it`, and
  uncertainty, plus the lottery escape `skip`. Receiving the response resolves
  the Wait and releases the affected Brick subject to every other gate.
  Waiting longer records the review and chooses the next
  `review_not_before`. Follow-up enters an enabling-Brick route; changing the
  blocker re-enters typed obstacle classification. `skip` records only typed
  review deferral, cooldown, and future review pressure: it leaves the Wait,
  its `review_not_before`, and every claimed outcome unchanged. No outcome
  completes the affected Brick.
- **WRK-053 [core] — Follow-up remains honest work.** If a Wait review reveals
  a human action, that action becomes an ordinary enabling Brick. Its accepted
  handoff preserves or reactivates the Wait after completion without a gap in
  gating. Drafting, sending, or observing an external message remains subject
  to explicit effect approval; creating a follow-up Brick never claims that a
  message was sent.
- **WRK-054 [core] — Wait history is evidence.** Activation, each review,
  policy change, follow-up handoff, reclassification, and resolution are typed
  history. They do not fabricate focus, progress, completion, or ExternalEntity
  behavior.
- **WRK-055 [standard] — Early source observation is a proposal.** A trusted
  source may observe evidence that the awaited response or condition changed
  before `review_not_before` and create an attributed candidate-resolution
  opportunity. It never silently resolves the Wait, marks the affected Brick
  done, or rewrites the review threshold.
- **WRK-010 [core] — Cooldown plus memory.** Explicitly deferring the served
  Brick after a symptom creates a short, replay-deterministic cooldown while
  preserving longer-term evidence and pressure. A recovery that returns to
  the Brick without deferral creates no skip cooldown. Neither path changes
  importance.
- **WRK-011 [standard] — Scoped fatigue.** An accepted reaction may apply
  tiredness or boredom to a Domain branch, producing a bounded decaying signal.
  The symptom alone never chooses scope or changes Domain.
- **WRK-012 [standard] — Taxonomy watch.** Repeated attributed `other` evidence
  may create a taxonomy-review opportunity. Human, skill, or powered-up
  judgment proposes a label; acceptance is explicit and versioned.
- **WRK-013 [core] — Contextual skip.** Ordering, effort/impact
  classification, Wait and WIP reviews, approvals, repeatable work, and habit
  opportunities each have distinct skip semantics and never reuse served-work
  evidence incorrectly. The common lottery escape guarantees navigation, not
  one generic domain event.
- **WRK-047 [core] — Atomic symptom resolution.** A final reaction records the
  selected symptom and accepted reaction atomically. `skip anyway` records the
  symptom without another remediation and applies the ordinary cooldown.
  Reverse navigation from a reaction returns to the symptom screen; reverse
  navigation from the symptom screen returns to the original Focus screen.
  Neither path records evidence, applies cooldown, changes Domain, or consumes
  a new draw.
- **WRK-067 [core] — Big has several recoveries.** The `big` reaction offers
  `break_into_parts`, `collect_more_context`, `learn_about_subject`, explicit
  `skip_anyway`, and uncertainty. Break enters the previewed decomposition
  route without mutation; only accepted structure records `big` and the break
  atomically. Collect and learn each enter contextual Feed for one enabling
  Brick, with no mutation until the preview confirms its ordinary Nature,
  local importance insertion, and Dependency into the served Brick. That
  atomic confirmation records `big` and the recovery; the Dependency, rather
  than a redundant skip cooldown, keeps the original Brick from ordinary
  execution. `skip_anyway` records `big` plus cooldown and creates no recovery.
  Explicit `/break` reaches decomposition without requiring a prior symptom;
  `hard` or `vague` assistance may offer the same action when evidence
  supports it. Nature and title alone never do.
- **WRK-068 [core] — Tired offers recovery, not diagnosis.** The `tired`
  reaction offers `easier work`, `change subject`, `pause for now`, explicit
  `skip anyway`, and uncertainty. These are provisional human choices on
  UX-S07; selecting `tired` alone records no evidence. `Easier work` follows
  WRK-069, `change subject` follows WRK-070, and `pause for now` follows
  WRK-071. Empty-candidate, no-Domain, and multi-membership recovery remains
  bounded by `OPEN-SKIP-001` rather than being guessed from the symptom.
- **WRK-069 [core] — Choosing easier work completes the reaction.** UX-S08
  selection is the final `tired` reaction. In one event-bound transaction it
  records `tired`, the served Brick's ordinary cooldown, the complete shown
  candidate set, the chosen candidate, IMP-038 weak relative-effort evidence,
  and FOC-044 contextual forecast evidence. If the served Brick is current,
  the same transaction closes its focus interval and clears the focus pointer
  while leaving it WIP; an unrelated current focus is never cleared. It then
  opens the chosen candidate as an ordinary focus proposal without starting
  it. Reverse navigation before candidate selection records nothing. After
  selection, semantic undo—not screen navigation—compensates the transaction.
- **WRK-070 [core] — A positive subject target completes its served reaction.**
  Selecting one Domain path on UX-S09 atomically records the originating
  `tired` or `bored` symptom, the served Brick's ordinary cooldown, the source
  and target paths, and both FOC-045 signals. If the served Brick is current,
  the transaction closes its focus interval and clears the focus pointer while
  leaving it WIP; an unrelated current focus is preserved. The core then
  performs the single target-scoped draw and presents its result through
  ordinary `Work:`/`Focus?` consent. Reverse navigation and `[m]ore options...`
  before target selection record nothing. After selection, semantic undo—not
  screen navigation—compensates the transaction. Drawing or proposing the
  target never changes active Domain; accepting its focus does so under
  FOC-017. `Skip anyway` records only the originating symptom and ordinary
  Brick cooldown; it infers no Domain signal.
- **WRK-071 [core] — Tired pause is evidence-bearing rest.** Choosing `pause
  for now` from UX-S07 atomically records `tired`, the served Brick's ordinary
  cooldown, and the accepted pause reaction. If that Brick is current, the
  same transaction closes its focus interval, clears focus, and leaves it WIP.
  If it was only proposed, it is not made WIP; an unrelated current focus is
  never cleared. The transition performs no forecast draw, changes no Domain,
  and creates no persistent `paused` lifecycle state. Unlike direct `/pause`
  under WRK-048, this path intentionally retains symptom and cooldown evidence
  because the user supplied both. It returns UX-S10 and never exits a surface
  process automatically.
- **WRK-072 [core] — Bored distinguishes escape from transformation.** UX-S11
  offers `change subject`, `make it more interesting`, explicit `skip anyway`,
  and uncertainty. Selecting `bored` alone records nothing. Subject change
  opens UX-S09 with `bored` as its pending symptom; transformation opens
  UX-S12. `Skip anyway` records `bored` plus ordinary Brick cooldown and no
  Domain, structure, or method claim. Reverse navigation preserves the prior
  served-work checkpoint without mutation.
- **WRK-073 [core] — Interesting-work remedies reuse explicit mechanisms.**
  UX-S12 offers `try a short sprint`, `break it into visible steps`, `find a
  better way`, and uncertainty. Sprint enters UX-S15 under WRK-076..080. Break
  enters the existing pending `/break` flow; only accepted structure records
  `bored` and the recovery, with no redundant cooldown. Find enters UX-S13.
  No option creates an engagement score, changes importance, or lets the core
  invent motivational advice.
- **WRK-074 [core] — Better-way acceptance is one enabling recovery.** UX-S13
  classification followed by UX-S14 acceptance creates exactly one FED-032
  Brick, its accepted parent and Domain placement, lazy Nature claim, local
  importance evidence, and a Dependency into the served Brick in one
  transaction. The same transaction records `bored` plus `find a better way`;
  the Dependency replaces ordinary skip cooldown. Rejecting or reversing any
  uncommitted step creates no Brick, evidence, or relationship. Powered-up and
  Skill follow FED-033. If edit explicitly removes the prerequisite relation,
  the preview must say that this is independent improvement work; acceptance
  then applies the served Brick's ordinary cooldown because no Dependency
  gates it.
- **WRK-075 [core] — Organization is a symptom-aware recovery target.**
  Choosing UX-S09 `organize and review` atomically records the originating
  `tired` or `bored` symptom, the served Brick's ordinary cooldown, inferred
  source-branch fatigue, and FOC-046 family affinity. It closes only the served
  current focus, leaving it WIP, and preserves unrelated focus. The core then
  performs one organization-family draw without changing active Domain or
  starting work. Subsequent meta-opportunities return only through ordinary
  weighted continuity; this action never establishes a persistent mode.
- **WRK-076 [core] — A short sprint is an honest focus timebox.** Choosing
  `try a short sprint` opens a duration decision; it does not yet record
  `bored`, start focus, or start a clock. An accepted sprint asks the user only
  to give the Brick a bounded attempt. It is not a Brick, estimate, deadline,
  schedule, completion criterion, progress observation, or claim that work
  occurred for the entire interval. Expiration is therefore called `Sprint
  time is up`, never `Sprint complete`.
- **WRK-077 [core] — Sprint duration is explicit and configurable.** The dumb
  factory choices are 5, 15, and 25 minutes, with 25 minutes selected by
  default and described as `a Pomodoro`. `*` or Enter accepts that visible
  default; a number accepts its row. A custom route remains available, and
  changing the factory menu or default is versioned configuration rather than
  inferred behavior. Starting another sprint returns to the same picker with
  the just-finished duration as its visible default when that duration remains
  valid.
- **WRK-078 [core] — Duration acceptance is focus consent.** Accepting a
  duration atomically records `bored` plus `short sprint`, starts the timebox,
  and starts or resumes focus on the served Brick; it does not ask `Focus?`
  again or add an ordinary skip cooldown. If another Brick was current, the
  ordinary focus-switch rule leaves that Brick WIP. The start fact identifies
  the focused Brick, chosen duration, canonical target instant, origin, and
  effective configuration. It does not create observed effort.
- **WRK-079 [core] — An active timebox does not trap interaction.** While the
  sprint runs, the current-focus screen retains ordinary `done`, `skip`, and
  slash-palette actions. Opening a palette, typing a draft, asking for help,
  or entering skip diagnosis does not itself stop the timebox. Accepted
  completion, pause, skip, or focus switch closes it early with the truthful
  terminal reason. Reverse navigation from an uncommitted branch returns to
  the still-running focus. Browsing `/next` alone does not clear focus or the
  timebox; accepting another focus applies the focus-switch outcome.
- **WRK-080 [core] — Expiration preserves work and offers a bounded choice.**
  On elapsed time, the Brick remains WIP and focused while UX-S17 offers
  `continue`, `another sprint`, `done`, `pause`, and uncertainty. `Continue`
  removes only the elapsed timebox and keeps focus without a new timing claim.
  `Another sprint` returns to UX-S15 and starts a new timebox only after a
  duration is accepted. `Done` follows WRK-049. `Pause` follows WRK-048 and
  does not manufacture another `bored` or skip observation. Expiration never
  changes importance, effort, progress, Domain, or lifecycle by itself.
- **WRK-081 [core] — Fear chooses recovery without becoming an axis.**
  Selecting `fear` on the served-work symptom screen opens UX-S18 with
  `validate the risk first`, `make a safer first move`, `get support`, `skip
  anyway`, and uncertainty. Fear alone is provisional navigation and creates
  no risk score, severity, lifecycle state, importance evidence, or hidden
  psychological inference. Skip anyway records `fear` plus the ordinary
  served-Brick cooldown and nothing about the cause.
- **WRK-082 [core] — Validation and safer moves become explicit prerequisites.**
  Validation and safer-move text remain drafts through UX-S19..S21. Accepting
  the complete preview atomically creates one FED-034 enabling Brick using
  FED-030's sibling, effective-Domain, Dependency, and local lazy-importance
  baseline, then records `fear` plus the selected recovery. The Dependency
  replaces ordinary skip cooldown. Validation sets phase `validation`; safer
  move infers no phase. Rejecting, reversing, or abandoning the draft creates
  no Brick, symptom evidence, relationship, or random consumption.
- **WRK-083 [core] — Support reuses handoff mechanisms.** UX-S22..S23 select
  one ExternalEntity and one explicit support form without recording `fear`.
  Accepted advice follows FED-035 and WRK-050's request-plus-successor-Wait
  handoff. Accepted collaboration creates one enabling preparation Brick and
  Dependency without inventing a meeting or delegation. Accepted delegation
  enters the existing preview-and-approval lifecycle under WRK-029..034. The
  first accepted canonical handoff records `fear` plus `get support`; a real
  Dependency or active delegation replaces ordinary cooldown. Any route still
  awaiting confirmation remains reversible and evidence-free.
- **WRK-084 [core] — Vague distinguishes content from missing work.**
  Selecting `vague` opens UX-S24 with `goal`, `information`, `first step`,
  `skip anyway`, and uncertainty. Vague alone is provisional navigation. Goal
  enters FED-037 descriptive clarification; information enters FED-038
  contextual Feed; first step opens UX-S27. Skip anyway records `vague` plus
  ordinary cooldown without guessing what was unclear.
- **WRK-085 [core] — Direct clarification keeps the Brick in place.** Goal
  text and its Description change remain drafts through UX-S25..S26. Accepting
  the preview atomically applies the canonical Description Raw revision and
  records `vague` plus `clarify goal`. It creates no Brick, Dependency,
  cooldown, importance evidence, phase, or lifecycle change. A served current
  focus remains focused and returns to its sober continuation; an unstarted
  proposal returns to ordinary Focus consent. Rejection or reverse navigation
  creates no Raw revision or symptom evidence.
- **WRK-086 [core] — Missing work must be accepted before it blocks.** An
  accepted information, learning, decomposition, or support preview records
  `vague` plus the chosen recovery atomically. Enabling work and accepted
  decomposition use their existing Dependency or child structure instead of
  ordinary cooldown; rejected and provisional routes remain evidence-free.
  Asking for help reuses UX-S22..S23 with `vague` carried rather than `fear`.
  A direct skip from UX-S27 records only `vague` plus cooldown.
- **WRK-087 [core] — Hard is difficulty, not a forced diagnosis.** Selecting
  `hard` opens UX-S28 with `learn or practice first`, `break into smaller
  parts`, `find an easier approach`, `get help`, `skip anyway`, and
  uncertainty. Hard remains distinct from `big`, `vague`, and `fear`, but may
  share their recoveries. Choosing decomposition preserves the explicit
  `hard` symptom and records `break into smaller parts`; it never silently
  converts the symptom to `big` or records both. A hard reaction is not an
  EffortProfile classification, hours estimate, or direct effort comparison.
- **WRK-088 [core] — Hard recoveries commit through their existing previews.**
  Learning or practice enters FED-040 contextual Feed; decomposition reuses
  UX-B00..B02; easier approach reuses UX-S13..S14; and support reuses
  UX-S22..S23. The symptom remains provisional through every builder. The
  accepted existing preview atomically records `hard` plus the chosen recovery
  and uses its Dependency or child structure instead of ordinary cooldown.
  Skip anyway records only `hard` plus cooldown. Rejection and reverse
  navigation remain evidence-free.
- **WRK-089 [core] — Less important distinguishes order, time, and subject.**
  Selecting `less important` opens UX-S30 with `order it lower`, `later`,
  `change subject`, `skip anyway`, and uncertainty. The symptom alone does not
  change importance, forecast probability, dates, Domain, focus, or cooldown.
  Order follows WRK-090, later follows WRK-091, subject change follows WRK-092,
  and skip anyway records only `less_important` plus ordinary cooldown.
- **WRK-090 [core] — Reordering begins with the first real judgment.** Choosing
  `order it lower` opens IMP-039's targeted continuous ordering without a
  mutation. The first accepted canonical comparison atomically records
  `less_important`, `order it lower`, that comparison, and ordinary served
  cooldown; if the served Brick was current, it also closes focus and leaves
  the Brick WIP. Subsequent comparisons are ordinary `/order` evidence. Exiting
  before the first answer records nothing. With no comparable lower sibling,
  the route returns an educational no-target result and records nothing rather
  than inventing a move.
- **WRK-091 [core] — Later changes eligibility, not importance.** Choosing
  `later` first opens an explicit date choice under UX-018. Accepting an
  absolute instant atomically records `less_important` plus `later` and applies
  that instant as `not_before`, leaving importance untouched. The time gate
  replaces ordinary cooldown. A served current focus is closed and left WIP;
  unrelated focus is preserved. Cancelling or reversing before the instant is
  accepted changes nothing.
- **WRK-092 [core] — Subject change preserves the human list.** Choosing
  `change subject` opens UX-S09 with `less_important` carried provisionally.
  Selecting one target Domain atomically records the symptom, reaction, source
  and target paths, and ordinary served cooldown; it closes only a served
  current focus and leaves it WIP. The core then follows FOC-047 for one scoped
  draw. It records no importance change or Domain fatigue, and the active
  Domain changes only if the replacement Focus is accepted.
- **WRK-093 [core] — Other preserves an unexplained obstacle verbatim.**
  Selecting `other` opens UX-S31 and records nothing. Nonblank text is kept as
  pending symptom evidence and shown in UX-S32 before acceptance; it is event
  evidence, not a Raw, Description, custom symptom, Domain, or hidden
  classification. Accepting atomically records `other`, the exact entered
  text, and ordinary cooldown. If the served Brick was current, it closes only
  that focus and leaves the Brick WIP; unrelated focus remains untouched.
  Edit, rejection, and reverse navigation before acceptance create no event.
- **WRK-094 [standard] — Other evidence feeds a separate taxonomy watch.**
  Repeated relevant `other` evidence may make WRK-012's typed taxonomy-review
  opportunity eligible under versioned, replay-deterministic thresholds. That
  later review may propose mapping a recurring pattern to an existing symptom
  or adding a versioned symptom, but acceptance is explicit and never rewrites
  historical verbatim evidence. One `other` answer never infers blocked,
  waiting, tired, Domain fatigue, importance, or a new category. Exact text
  grouping, thresholds, window, and decay remain calibration concerns.
- **WRK-095 [core] — Mechanical symptom discovery.** Choosing uncertainty on
  UX-S01 asks one behavioral question per screen and follows this factory tree:

  ```text
  Q0. Must something outside this Brick happen before you can continue?
  ├─ yes → blocked_or_waiting
  └─ no
     Q1. Is the main problem that the result, required information, or first
         step is unclear?
     ├─ yes → vague
     └─ no
        Q2. Would independently tracked parts make this manageable?
        ├─ yes → big
        └─ no
           Q3. Is the work clear and small enough, but beyond your current
               knowledge, skill, or available approach?
           ├─ yes → hard
           └─ no
              Q4. Have changed facts or context made this Brick stale?
              ├─ yes → out_of_date
              └─ no
                 Q5. If this Brick and more-important work were mutually
                     exclusive forever, would you leave this Brick undone?
                 ├─ yes → less_important
                 └─ no
                    Q6. Is insufficient energy the main obstacle?
                    ├─ yes → tired
                    └─ no
                       Q7. Is lack of interest or stimulation the main obstacle?
                       ├─ yes → bored
                       └─ no
                          Q8. Is worry about risk or consequences the main
                              obstacle?
                          ├─ yes → fear
                          └─ no  → other
  ```

  The order is versioned and deterministic. `main` makes the result the one
  symptom being addressed in this interaction; it does not claim that every
  other symptom is false or erase earlier evidence.
- **WRK-096 [core] — Uncertainty probes preserve each split.** Question mark
  at Q0..Q8 does not choose a branch. It explains the current distinction with
  one example from each side and asks the corresponding alternate probe:

  | Split | Alternate probe | `yes` | `no` |
  |---|---|---|---|
  | outside prerequisite | If that outside fact changed now, could you proceed without changing the Brick? | `blocked_or_waiting` | Q1 |
  | unclear work | Would a clearer result, more information, or a defined first step be enough to get moving? | `vague` | Q2 |
  | one piece or parts | Would one `done` hide progress worth tracking separately? | `big` | Q3 |
  | clear but difficult | Do you know what needs doing but not how to do it effectively? | `hard` | Q4 |
  | stale intention or content | Would current facts make you archive, replace, or revise this Brick rather than merely postpone it? | `out_of_date` | Q5 |
  | relative importance | If only this Brick or more-important work could ever be completed, would you give this one up? | `less_important` | Q6 |
  | energy | Would rest or easier work help without changing the Brick? | `tired` | Q7 |
  | interest | Would a more engaging method help without changing the intended result? | `bored` | Q8 |
  | perceived risk | Would validating or reducing a perceived risk help? | `fear` | `other` |

  A second uncertainty at the same split leaves the interaction pending rather
  than guessing. System help remains `/help` through the slash palette.
- **WRK-097 [core] — Discovery is provisional through reaction.** Every tree
  question and symptom result is an uncommitted navigation checkpoint. The
  result is unequivocal only after explicit leaf confirmation. Confirming a
  typed leaf opens its existing reaction; confirming `other` opens its
  verbatim explanation. Neither confirmation records a symptom: WRK-047 still
  commits only the final accepted reaction. Rejection returns to the direct
  symptom screen, and reverse navigation restores the exact preceding answer
  without an event, cooldown, Domain signal, focus change, or random draw.
- **WRK-098 [core] — Out of date is stale meaning, not low importance.**
  Selecting `out_of_date` opens UX-S35 with `archive it`, `replaced by newer
  Work`, `update it`, `skip anyway`, and uncertainty. It does not mean merely
  less important or temporarily ineligible: those remain `less_important` and
  `not_before`. The symptom is provisional until one reaction commits. The
  replacement route enters canonical supersession with explicit lineage; the
  update route keeps the same active identity and enters ordinary inspected
  editing; skip records only `out_of_date` plus cooldown.
- **WRK-099 [core] — Archive is reversible retirement with one review.**
  Accepting `archive it` atomically records `out_of_date`, changes the Brick
  from `active` to `archived`, closes its current focus or WIP state, preserves
  its prior importance evidence and local-neighborhood snapshot, and creates
  exactly one unresolved `archive_relevance_review` marker. It applies no
  ordinary skip cooldown because the Brick is no longer executable. The
  archive event is eligible for immediate semantic undo when its recorded
  preconditions still hold; later review-based restoration is a new forward
  action and never erases the archive history.
- **WRK-100 [core] — Archive review has bounded forward outcomes.** A selected
  `archive_relevance_review` offers `keep archived`, `restore it`, `update and
  restore`, `newer Work replaced it`, typed review skip, and uncertainty.
  Keeping it archived resolves this one automatic marker and creates no
  periodic nag. Restore reactivates the same Brick and deterministically seeds
  its complete sibling order from the last valid local neighborhood; the
  restored placement is explicitly uncertain and creates one lazy
  `importance_run_review`. Update and restore first applies an accepted edit
  to the same Brick and then follows the same restoration. Newer Work enters
  canonical supersession with lineage. Review skip leaves status and marker
  unchanged, applying only review cooldown and pressure. Exact structured edit
  selection and supersession relationship transfer remain with their owning
  open decisions rather than being guessed here.
- **WRK-101 [core] — Updating dispatches by human meaning, not storage field.**
  `update it` and `update and restore` enter one non-mutating update hub whose
  closed first-level purposes are `meaning`, `behavior`, `plan`, `timing`,
  `context`, `source material`, and read-only `view everything`. These are UI
  dispatch purposes, not Brick fields, status values, event kinds, or another
  ontology axis. Meaning reaches title or Description Raw; behavior reaches
  Nature, Template, or the applicable run/repetition behavior; plan reaches
  parts, Dependencies, Waits, or Delegation; timing reaches the applicable
  `not_before`, `best_before`, deadline, schedule, or recurrence route; context
  reaches Domains, ExternalEntities, and related Work; source material reaches
  RawLinks or external-source reconciliation; and view everything reuses
  read-only `/show` before restoring the hub. Every branch invokes a closed
  canonical operation with its own validation and preview. There is no generic
  field editor, arbitrary patch payload, or catch-all metadata mutation.
- **WRK-102 [core] — Each accepted update is one reversible semantic action.**
  A branch drafts and previews one typed change at a time. Accepting the first
  change from an active out-of-date flow atomically records `out_of_date` with
  that change and retains the same Brick identity and active lifecycle;
  browsing, inspecting, editing a draft, rejecting, or leaving records no
  symptom. The result may return to the hub for another independent change;
  later changes do not duplicate the originating symptom. Each accepted change
  has its own history and semantic-undo boundary rather than joining an
  unbounded cross-domain megadraft. A focused Brick remains focused and a
  pending Focus proposal is revalidated. From `update and restore`, the first
  accepted change atomically performs WRK-100 restoration, resolves the archive
  review, and creates its lazy importance review; leaving before acceptance
  keeps the Brick archived. Returning to Work never starts focus silently.

## Time

- **WRK-014 [core] — Three date meanings.**

  ```text
  not_before  — ordinary execution must not be proposed before this instant
  best_before — usefulness degrades after this instant
  deadline    — an external commitment or consequence occurs at this instant
  ```

- **WRK-015 [core] — Dates inform forecast, not importance.** Date pressure,
  notices, and overdue state affect focus chance and explanation without
  rewriting human importance.
- **WRK-016 [core] — Contextual later.** `later` appears only where a proposal
  can honestly be deferred. It always shows and records an explicit absolute
  date; it is not a universal response.
- **WRK-017 [core] — Deterministic tick.** Every command advances due temporal
  rules from its canonical clock. An explicit administrative `tick` performs
  the same advancement without inventing other work.
- **WRK-018 [standard] — Discreet notices.** Date notices are deduplicated,
  inspectable, acknowledgeable or snoozable as applicable, and rendered
  discreetly in secondary context rather than hijacking every screen.
- **WRK-041 [core] — Separate temporal meanings.** The core distinguishes an
  exact instant, a civil date, a habit day, and a workday. An exact instant is
  one unambiguous point on the timeline; a civil date is an ordinary calendar
  date in a named zone; habit day and workday are derived operational labels.
  No operational label changes the underlying instant or civil date.
- **WRK-042 [core] — Exact-instant safety.** Clock-specific facts such as
  flights, appointments, and timed deadlines retain both an absolute instant
  and their named IANA time zone. They render with the corresponding local
  date, clock time, and offset. A day boundary never rounds, delays, advances,
  or otherwise reinterprets them. Ambiguous clock input must be resolved
  explicitly before it becomes canonical.
- **WRK-043 [core] — Configurable operational days.** Habit day and workday
  each use a configurable local `starts_at` boundary in the configured
  operational IANA time zone. Activity before a boundary belongs to the
  preceding nominal operational day while retaining its real timestamp and
  civil date.
- **WRK-044 [standard] — Boundary scope.** Habit-day attribution controls
  habit opportunity windows, outcomes, and streak projections only. Workday
  attribution controls day-scoped work recaps, statistics, quotas, and focus
  continuity only. A habit schedule may explicitly override the profile's
  habit-day boundary. Neither boundary changes `not_before`, `best_before`,
  `deadline`, or any other exact instant.
- **WRK-045 [core] — Whole-session attribution.** A continuous work session is
  attributed wholly to the workday in which it started, even when it ends
  after the workday boundary. The core does not split one session
  automatically at that boundary.
- **WRK-046 [core] — Relative preparation timing.** A preparatory Brick may
  derive `not_before`, `best_before`, or `deadline` from an explicit signed
  offset to a named exact-instant anchor on its scheduled commitment. The
  relative constraint and its effective absolute instant are inspectable and
  replay-deterministic. `not_before` controls when the preparation can first
  appear; `best_before` expresses preferred completion; `deadline` records the
  actual external consequence boundary. A Template may propose offsets but
  cannot silently treat one meaning as another.

## Standing work and recurrence

- **WRK-019 [standard] — Standing execution.** Finishing one run of a standing
  Brick records an execution outcome, clears focus/WIP as applicable, and
  leaves the standing responsibility active.
- **WRK-020 [standard] — Living checklist.** All open entries render
  together. Bought or resolved entries leave the open view but remain in
  history; unresolved entries remain. Empty state is dormant, not done.
- **WRK-021 [standard] — Repeatable Brick.** Completing a repeatable execution
  may finish the Brick terminally or schedule the same identity behind one
  future `not_before`. It is never reinserted in importance.
- **WRK-022 [standard] — Deterministic jitter.** An approximate return such as
  six months plus or minus three months chooses and records one replay-safe
  date, preventing a batch of completions from necessarily returning together.
- **WRK-023 [standard] — Recurring obligation.** A standing series releases
  independently completable occurrence Bricks. Unpaid occurrences remain open
  and may coexist with later periods.
- **WRK-024 [standard] — Habit.** A habit retains one standing identity
  while applicable windows record `done` or an unfulfilled outcome. Expired
  opportunities do not accumulate as overdue task backlog.
- **WRK-025 [standard] — Blocked or paused habit.** Inapplicable, blocked,
  or explicitly paused windows do not fabricate failure or break a streak.
- **WRK-026 [standard] — Derived motivation.** Streaks and compact projections
  such as `[x][x][x][-][x][x]` derive from occurrence history. Before an
  explicit outcome would end a streak, UI may confirm the concrete consequence.
- **WRK-027 [calibration] — Introspection.** Repeated skips or unfulfilled
  intentions can create a review using configurable evidence thresholds.
  Possible remedies remain explicit: revise schedule, add a dependency or
  enabling Brick, pause, retire, or gather more evidence.
- **WRK-062 [core] — Nature-owned skip consequences.** Finalizing a typed
  skip on an ordinary-lottery execution always grants an immediate
  replay-deterministic cooldown, so the same opportunity cannot nag through
  an immediate redraw. What happens after that cooldown follows the semantic
  variant rather than one universal pressure rule:

  - a `repeatable_run` records deferral but no missed window, debt, overdue
    occurrence, or gap in history; after cooldown it returns through its
    ordinary availability and aging policy;
  - a `habit_window` never becomes overdue task backlog and follows its
    schedule shape under `WRK-063`;
  - skipping a released `recurring_obligation` occurrence leaves that finite
    occurrence open. After cooldown, recorded avoidance and its ordinary
    `best_before` or `deadline` signals may increase its selection pressure;
    a later period never erases it;
  - an active `scheduled_commitment` is hard precedence under `FOC-030`, not
    an ordinary-lottery execution, and therefore exposes truthful
    commitment outcomes instead of this skip route.

  A skip never changes importance order. Cooldown and pressure curves are
  replay-safe calibration parameters; the distinctions above are not.
- **WRK-063 [standard] — Habit skip follows schedule shape.** For an
  applicable fixed-slot habit opportunity, finalizing skip closes that slot
  with the canonical unfulfilled outcome unless the accepted reaction makes
  the slot blocked, paused, or inapplicable under `WRK-025`. It does not return
  as debt. For a quota-window habit, skip applies cooldown but does not close
  the window or itself record the window-wide failure: the opportunity
  remains eligible while the quota is unmet and still achievable. Its chance
  may respond to remaining time and schedule deficit, not to a fabricated
  overdue occurrence. The schedule boundary derives any unfulfilled outcomes
  from the unmet quota.
- **WRK-064 [standard] — Honest standing-history projections.** A compact
  sequence may show only real discrete opportunities. Habit checks and gaps
  derive from applicable habit-window outcomes. A `repeatable` Brick has no
  expected windows, so it may expose completion count and `Last completed`
  but never inserts a gap merely because no execution occurred. A recurring
  obligation exposes open and resolved occurrence state rather than a streak;
  an unresolved occurrence is debt, not a missed historical cell. Exact
  glyphs and compact layout remain surface work under `OPEN-UX-001`.
- **WRK-065 [core] — Explicit non-current WIP outcomes.** An accepted
  `wip_review` offers resume, defer this review, complete, or return the Brick
  to idle. Resume atomically opens a new focus interval and makes the reviewed
  Brick current; any previous current Brick remains WIP under `WRK-001`.
  Review skip records only deferral of this review and its cooldown: it does
  not open served-work symptom diagnosis or mutate WIP. Completion uses the
  ordinary direct completion outcome. Returning to idle clears WIP while
  preserving the Brick, importance, Domain membership, and history; it is not
  completion, pause, or skip evidence. Archive and supersede remain explicit
  contextual-palette outcomes. Every mutation is semantically undoable when
  its recorded preconditions still hold.
- **WRK-066 [core] — Explicit scope-closure outcomes.** A selected
  `scope_closure_review` offers complete the parent, add more work, or defer
  only this review. Completion applies direct `done` to the parent and remains
  semantically undoable. `add more work` opens a contextual Feed route without
  mutation; confirming a new locally ordered child keeps the parent active,
  invalidates the review, and returns execution to descendant selection.
  Review skip records only typed scope-review deferral and cooldown; it never
  opens served-work symptom diagnosis or makes the parent executable. The
  contextual palette may inspect or reactivate one completed child and expose
  valid `archive` or `supersede` routes; unresolved subtree consequences remain
  under `OPEN-TREE-001`.
- **WRK-028 [standard] — Event-triggered opportunity.** A supported canonical
  source event may idempotently release one opportunity on an existing
  compatible standing Brick. This is closed core data, not generic automation.
## Delegation

- **WRK-029 [standard] — ExternalEntity target.** Delegation targets an
  ExternalEntity and never consumes human WIP merely because it is active.
- **WRK-030 [standard] — Mandatory follow-up policy.** Before the initial
  notice can be approved, every Delegation chooses exactly one:

  ```text
  once | every | explicitly none
  ```

  The policy governs outbound follow-up under WRK-060, not internal Delegation
  review. Repeating policy creates approval-bearing follow-up opportunities
  and never authorizes automatic messages.

- **WRK-031 [standard] — Nature-aware scope.**

  ```text
  brick_only | whole_scope | ask | disabled
  ```

  `whole_scope` derivatively covers current and future descendants and
  Nature-owned entries; `ask` stores the concrete choice; `disabled` still
  permits separate enabling work.

- **WRK-032 [standard] — Factory delegation scopes.**

  | Nature | Scope |
  |---|---|
  | `atomic_task` | `brick_only` |
  | `project` | `ask` |
  | `collection` | `brick_only` |
  | `repeatable` | `ask` |
  | `living_checklist` | `ask` |
  | `finite_checklist` | `whole_scope` |
  | `recurring_obligation` | `ask` |
  | `habit` | `disabled` |

  `scheduled_commitment` is intentionally absent until `OPEN-SCH-001`
  resolves whether delegation applies to attendance, preparation, the whole
  interval, or only selected Templates. An implementation must not infer a
  default from another Nature.

- **WRK-033 [standard] — Preview and reconciliation.** Initial notice,
  cancellation, follow-up, nudge, refusal, and reported completion preserve
  explicit previews and approvals. Existing human focus, WIP, or incompatible
  delegation inside a proposed whole scope must be reconciled first.
- **WRK-034 [standard] — No cascading truth.** A reported delegated outcome
  returns for Nature-aware validation and never cascades completion through a
  project tree.
- **WRK-056 [standard] — External-effect confirmation outcomes.** For one
  concrete pending external effect, `yes` approves that exact preview; `no`
  permanently rejects that effect instance without cancelling its Delegation
  or claiming that the underlying need was resolved; `later` chooses and
  records a new review instant; and an ordinary-lottery `skip` preserves both
  the effect and its existing review instant while recording only typed
  deferral, cooldown, and future pressure. Rejecting an effect never silently
  drafts or authorizes a replacement.
- **WRK-057 [standard] — Delegation transfers execution responsibility.** An
  active Delegation means the selected ExternalEntity, not the human user, is
  responsible for executing its resolved scope. Human collaboration is not
  represented by leaving the same covered work eligible for both parties.
  Concurrent human work uses explicit non-covered enabling Bricks,
  Dependencies, or sibling work with its own responsibility. Cancelling,
  refusing, or reporting completion routes through typed reconciliation before
  eligibility or completion changes; no Delegation outcome silently completes
  a project tree.
- **WRK-058 [standard] — Observed handoff activates Delegation.** Creating or
  editing a Delegation draft, previewing its notice, or approving an attempted
  send does not activate it. Exactly one observed handoff does: either a
  delivery adapter records successful delivery of the approved initial notice,
  or the human explicitly records `I already handed it off` for communication
  performed outside Little Ant. Delivery failure leaves the Delegation
  inactive and its scope human-executable. Successful delivery proves only the
  handoff, not that the recipient read, accepted, refused, or completed the
  work; those remain separate attributed outcomes. A later refusal enters the
  typed reconciliation route before human eligibility returns.
- **WRK-059 [standard] — Delegation owns its follow-up.** The mandatory
  `once | every | explicitly none` policy controls Delegation review and
  follow-up directly. Activation does not synthesize a Wait such as "waiting
  for the delegate." If the delegate or another source later reveals a
  distinct gate—for example, Legal approval—the user may explicitly add or
  classify that Wait against the affected Brick while retaining the
  Delegation. Its review history, pressure, and resolution remain separate
  from the Delegation's follow-up history and outcomes.
- **WRK-060 [standard] — Follow-up policy governs outbound handoffs.** The
  mandatory policy never disables internal Delegation review:

  - `once` permits at most one recorded follow-up handoff after the initial
    notice. A rejected draft, declined effect, failed delivery, or other
    attempt without handoff does not consume it. Once consumed, unresolved
    reviews may propose reconsidering, escalating, taking responsibility back,
    changing policy, or another typed remedy, but not another automatic
    follow-up proposal.
  - `every` may schedule another approval-bearing follow-up proposal after
    each unresolved review and recorded prior handoff. It never sends without
    the ordinary complete preview and approval.
  - `explicitly none` creates no automatic outbound follow-up proposal. The
    human may still initiate one explicitly or change policy.

  All three retain internal status review when warranted. Review and outbound
  effect keep distinct histories, cooldowns, pressure, and outcomes.
- **WRK-061 [standard] — Repeated follow-up has a soft cap.** Under `every`,
  automatic outbound proposals pause after
  `delegation.unanswered_follow_up_soft_cap` recorded follow-up handoffs with
  no meaningful outcome; the factory value is `2`. Attempts without handoff do
  not increment the count. The next warranted internal review offers typed
  strategy changes: allow exactly one more follow-up, take execution back,
  reassign, or enter an explicit escalation-Brick route. Continuing extends
  the allowance by one and never resets evidence or grants automatic sending.
  Taking back or reassigning follows Delegation reconciliation; escalation
  creates nothing before the ordinary guided Brick preview and confirmation.

## Place context

- **WRK-035 [standard] — Place conditions.** A Brick may have hard or soft
  conditions associated with a named Place.
- **WRK-036 [standard] — Attributed observations.** Current location is a
  time-bounded, attributed observation from a human or adapter. It affects
  eligibility or chance only within its declared strength and validity.
- **WRK-037 [standard] — Privacy boundary.** Adapters provide observations;
  the core does not continuously track location or silently perform external
  actions.

## Schedule semantics

- **WRK-038 [standard] — Habit schedule shapes.** A habit schedule resolves to
  either fixed slots or a quota window. A fixed slot anchors an opportunity to
  a recurring calendar position. A quota window requires a positive completion
  count within a positive number of days, weeks, months, or years. Both are
  canonical structured data; neither depends on interpreting stored prose.
- **WRK-039 [core] — Monthly anchor clamping.** A monthly fixed slot stores its
  intended day from 1 through 31. In a month without that day, the occurrence
  uses the month's last valid day. Later occurrences are always calculated
  from the intended day rather than the preceding adjusted date, so an anchor
  of 31 produces January 31, February 28 or 29, March 31, April 30, and May 31
  without drift.
- **WRK-040 [core] — Discrete habit outcome.** Every applicable habit
  opportunity records one discrete outcome: `done` or the canonical
  unfulfilled outcome chosen under `OPEN-WRK-002`. The 1.0 core does not add
  generic target quantity, unit, observed value, or percentage-progress fields
  for habits. A desired amount such as pages, minutes, distance, or repetitions
  may remain in the title, description, completion criterion, or optional
  execution note without changing the outcome model.

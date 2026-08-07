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
- **WRK-134 [core] — Wait pressure starts only after its review gate.** Before
  `review_not_before`, an active Wait contributes no selectable review. At the
  instant it opens, its one `wait_review` opportunity receives positive base
  weight. Thereafter a monotonic, bounded age term grows from elapsed time
  beyond that instant; bounded terms may also reflect explicit review
  deferrals, completed follow-up handoffs without a meaningful response, and
  the forecast consequence of the affected Work. No term makes the review
  hard precedence, due, overdue, or guaranteed on an Nth draw. One Wait still
  contributes one ticket. Review skip applies cooldown, then increments only
  the bounded deferral term. `Wait longer` and a completed follow-up choose a
  new `review_not_before`, reset post-opening age, and retain inspectable
  history terms.
- **WRK-135 [standard] — Historical timing requires comparable samples.** A
  human-response Wait uses the factory three-day suggestion until at least
  three resolved Waits for the same ExternalEntity and compatible ContactPoint
  family contain both handoff and meaningful-response instants. The robust
  median response duration then marks the nearest existing UX-W00 preset;
  ties prefer the longer duration. It never invents a hidden custom date or
  edits the factory options. Old samples decay from current suggestion
  influence without leaving history. Powered-up or Skill may use broader
  evidence only by marking one of those same visible choices with attribution.
- **WRK-136 [core] — Follow-up cadence is always chosen after a real
  handoff.** Selecting `follow up` creates ordinary enabling Work and no
  outbound claim. Only completing that Work or accepting its delivery receipt
  records a follow-up handoff. The same atomic transition keeps the Wait active
  and opens UX-W00 before it can return to the lottery; there is no periodic
  background message and no inherited cadence. Cancelling the follow-up Work
  returns to the unresolved Wait without claiming a handoff.
- **WRK-137 [standard] — Two unanswered follow-ups trigger strategy, not a
  third nag.** After two consecutive recorded follow-up handoffs without a
  meaningful response, the next selected review uses UX-W03 and omits the
  ordinary one-key `follow up` action. The human may wait longer, explicitly
  follow up again, change what is blocking the Work, or stop waiting. Follow
  up again remains possible because the cap is soft, but it must pass through
  this strategy screen and select another review instant after the handoff.
  A meaningful response, replacement Wait target, or resolved Wait resets the
  consecutive count; review skip and waiting longer do not. No strategy action
  delegates, escalates, sends, archives, or completes Work by implication.
- **WRK-138 [core] — Source-observed resolution stays a confirmation.** A
  candidate resolution stores the exact source, observation identity, time,
  affected Wait revision, and bounded evidence summary. UX-W02 offers
  `response received` for a human-response Wait or `condition met` for an
  event/condition Wait, plus keep waiting, inspect evidence, typed skip, and
  uncertainty. Accepting the positive outcome resolves only that Wait. Keep
  waiting settles this source proposal but preserves the Wait and its existing
  review gate; skip defers only the proposal. A trusted typed source may mark
  the positive row with attributed `*`, but no source or assisted mode may
  accept it.
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
  WRK-071. FOC-044 and FOC-060 define empty-candidate, no-Domain, and
  multi-membership recovery without guessing from the symptom.
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
  the preview atomically revises the canonical Raw attached as description and
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
  Direct `/update`, `update it`, and `update and restore` enter one
  non-mutating update hub whose closed first-level purposes are `meaning`,
  `behavior`, `plan`, `timing`, `context`, `source material`, and read-only
  `view everything`. These are UI dispatch purposes, not Brick fields, status
  values, event kinds, or another ontology axis. In particular, `plan` is a
  human route to composition, gates, and responsibility; it does not create a
  Plan entity, phase, or classification axis. Meaning reaches title or the Raw
  attached as description; behavior reaches only Nature under MOD-058; plan
  reaches parts, Dependencies, Waits, or Delegation; timing reaches the
  applicable `not_before`, `best_before`, deadline, schedule, or recurrence
  route; context reaches Domains and ExternalEntities; source
  material reaches RawLinks or external-source reconciliation; and view
  everything reuses read-only `/show` before restoring the hub. Every branch
  invokes a closed canonical operation with its own validation and preview.
  There is no generic field editor, arbitrary patch payload, or catch-all
  metadata mutation.
- **WRK-102 [core] — Each accepted update is one reversible semantic action.**
  A branch drafts and previews one typed change at a time. Accepting the first
  change from an active out-of-date flow atomically records `out_of_date` with
  that change and retains the same Brick identity and active lifecycle;
  browsing, inspecting, editing a draft, rejecting, or leaving records no
  symptom. The result may return to the hub for another independent change;
  later changes do not duplicate the originating symptom. Each accepted change
  has its own history and semantic-undo boundary rather than joining an
  unbounded cross-domain megadraft. A focused Brick remains focused unless a
  branch proves its target cannot represent that active focus and includes an
  explicit typed reconciliation in its preview; focus never changes silently.
  A pending Focus proposal is revalidated. From `update and restore`, the first
  accepted change atomically performs WRK-100 restoration, resolves the archive
  review, and creates its lazy importance review; leaving before acceptance
  keeps the Brick archived. Returning to Work never starts focus silently.
- **WRK-103 [core] — Meaning separates label from attached description.**
  Selecting `meaning` opens UX-S39 with exactly `title`, `description`, and
  uncertainty. There is no `both`: after either independent update, UX-S38
  already offers `update something else`. Title follows WRK-104. Description
  follows WRK-105 and denotes the MOD-056 RawLink projection rather than a
  Brick field. Merely choosing a branch records nothing.
- **WRK-104 [core] — Title revision preserves references.** Title editing
  starts with the complete current title selected and the ordinary quiet
  English-writing reminder. Printable input or paste replaces the selection;
  arrows collapse it without mutation. A nonblank changed title requires the
  complete before/after preview in UX-S41. Accepting changes only the canonical
  title and follows WRK-102 for the originating symptom. UUID, mnemonic handle,
  parent, sibling order, relationships, Domain membership, lifecycle, WIP, and
  focus remain unchanged. The previous title remains history and does not
  become an alias. Submitting unchanged text is an educational no-op with no
  event, revision, or `out_of_date` evidence.
- **WRK-105 [core] — Description revision keeps ordinary Raw identity.** If
  the Brick has a `RawLink(role = description)`, accepting changed original
  text appends a content revision to that same Raw and retains every prior
  revision in append-only history. It never replaces the Raw identity or
  creates a second Raw for that role. If no such link exists, the first accepted
  description atomically creates one ordinary text Raw and the MOD-057-valid
  link. Any existing English normalization on the changed original becomes
  explicitly stale rather than being copied forward as current; `/translate`
  remains its separate same-Raw route. Because the Raw may have other
  non-description consumers, the preview enumerates every other affected link
  or membership before a shared revision. Removing a description detaches only
  that link and preserves the Raw. Silent cloning, unlinking, deletion, or
  normalization is forbidden. Multiline interaction follows UX-159..161;
  generic Raw revision representation follows MOD-065.
- **WRK-106 [core] — Behavior update enters existing-Brick Nature choice.**
  Selecting `behavior` opens UX-S46 with the current Nature and its concise
  consequence, followed by the canonical nine-Nature choice and uncertainty.
  There is no separate Template, recurrence, run-policy, or generic behavior
  editor. Selecting the current Nature is an educational no-op with no event,
  revision, `out_of_date` evidence, or human-authority claim. Uncertainty
  reuses FED-024..027 over the existing Brick and its current facts; it cannot
  choose a Nature silently.
- **WRK-107 [core] — Nature change is one reconciled semantic action.** After
  a different Nature is selected, the core collects only target-required
  configuration and every MOD-059 reconciliation needed by incompatible
  active state. Until all are resolved, no confirmation action is available.
  UX-S47 then previews From, To, preserved facts, stopped or newly enabled
  behavior, target configuration, every reconciliation, and resulting focus
  or eligibility consequences. Yes applies the complete change atomically as
  one WRK-102 action; edit restores its nearest typed builder; no discards the
  reclassification and restores UX-S46. A change never reapplies a Template or
  rewrites Template provenance. MOD-077..081 derive every source-to-target
  transition from the two closed capability profiles.
- **WRK-108 [core] — Direct update is ordinary maintenance, not a symptom.**
  `/update #brick` enters the same hub as WRK-101 for an active or otherwise
  editable Brick without first requiring Focus, skip, `out_of_date`, or an
  archive review. Entering, inspecting, drafting, rejecting, or leaving the
  hub records no event. Each accepted typed change records only its own
  canonical mutation and retains its ordinary independent undo boundary; it
  never invents `out_of_date`, skip evidence, cooldown, restoration, or a
  lottery draw. The contextual palette may omit the argument only when its
  suspended InteractionEnvelope identifies exactly one Brick, and must render
  that resolved `#handle` and title before invocation. Otherwise the command
  requires ordinary typed Brick autocomplete. `/update` is the sole general
  update command: the core provides neither `/edit` nor `/plan` as an alias or
  overlapping shortcut.
- **WRK-109 [core] — Plan dispatches to structure, blockers, or
  responsibility.** Selecting `plan` opens one non-mutating choice among
  `structure`, `blockers`, `responsibility`, and uncertainty. Structure reaches
  the Brick's parent, child parts, or Nature-owned list items through their
  existing typed operations. Blockers reaches the human-oriented
  prerequisite classifier from WRK-009. Responsibility reaches Delegation.
  These are closed UI purposes, not a Plan object or generic relationship
  editor, and merely entering or leaving any route records nothing.
- **WRK-110 [core] — Planned blockers reuse facts without inventing a skip.**
  Entering the blocker classifier from `plan` presents the same five human
  situations and produces the same typed Dependency, Wait, `not_before`,
  Place, or event-condition result as the served-work classifier. It omits
  `skip anyway`: Escape or reverse navigation returns toward the Plan hub
  without a mutation, while uncertainty remains an explicit bounded route.
  Accepting a typed result records that prerequisite under WRK-102 plus only
  the update origin's already-declared atomic consequence. The classifier
  itself adds no `blocked_or_waiting`, `blocked`, or `waiting` skip evidence,
  cooldown, or focus refusal. The served-work origin retains its own
  defer-only action and commits symptom evidence only with a final accepted
  reaction under WRK-047.
- **WRK-111 [core] — Structure is intent-first, not Nature-first.** Selecting
  `structure` always offers `within larger Work`, `parts`, `list items`, and
  uncertainty, regardless of the current Nature, and assigns no dumb default.
  Selecting an intent first records nothing. `within larger Work` reaches
  parent or root movement without changing Nature. `parts` reaches the
  existing child/decomposition operation. `list items` reaches the existing
  ListEntry operation. The core does not maintain separate first-level
  structure menus for each Nature or hide a human intent because the current
  classification cannot yet represent it.
- **WRK-112 [core] — Incompatible structure proposes explicit behavior
  change.** If the selected structural intent is unsupported by the current
  Nature, no item, child, or relationship is created yet. The route first
  resolves a compatible Nature through MOD-045, MOD-059, and MOD-062. Parts
  distinguish one finite outcome (`project`) from open-ended members
  (`collection`) before collecting child drafts; list items distinguish finite
  from continuing ownership before proposing `finite_checklist` or
  `living_checklist`. Target-required configuration and every reconciliation
  for existing children, ListEntries, occurrences, focus, WIP, schedule, or
  other incompatible active truth are completed before the collector or final
  combined preview can proceed. The preview carries the same From, To,
  preserved, stopped, enabled, configuration, and consequence disclosure as a
  direct behavior change, plus the requested structure. The accepted Nature
  change and requested initial structure form one typed reversible action;
  rejection or reverse navigation preserves the original Nature, drafts, and
  structure completely. Template provenance is never reapplied or rewritten.
- **WRK-113 [core] — Reparenting preserves Domains and exposes structural
  divergence.** A move compares the Brick's direct Domain path set with the
  proposed parent's direct path set using only canonical equality, Domain-tree
  ancestry, set overlap, disjointness, and absence. If the sets differ, the
  preview shows both complete sets and states the mechanically derived
  relationship; it never labels them semantically similar, unrelated, close,
  or very different. Accepting `yes, keep current Domains` moves only the
  composition root and retains every Domain membership. `change Domains`
  suspends the move in the canonical context editor and returns to one combined
  preview; no relationship or membership changes before final acceptance. A
  move to a parent with identical memberships may omit the contrast block.
  Powered-up or Skill may mark `change Domains` and explain semantic evidence,
  but cannot alter the dumb comparison or apply a membership silently.
- **WRK-114 [core] — Parent selection is searchable and may draft a new
  scope.** The `within larger Work` route selects exactly one existing eligible
  Brick or literal root through handle/title autocomplete. Root removes the
  current parent. The moving Brick and all its descendants are excluded to
  prevent cycles; the current parent may appear as `current`, and selecting it
  is an educational no-op. A selected parent whose current Nature cannot own
  the requested child enters explicit WRK-112 reconciliation instead of being
  hidden. `New larger Work...` opens the ordinary title, Nature, Domain, and
  structure builders as a draft inside the suspended move. Neither a new
  parent nor a reparenting event exists until one complete combined preview is
  accepted; cancellation therefore cannot leave an orphan. The dumb selector
  has no default. Candidate eligibility is core-owned and identical across
  modes; assistance may rank or mark a candidate but never add an ineligible
  target or select one silently.
- **WRK-115 [core] — Parts reuse ordinary child Bricks instead of a project
  manager.** On a Nature that can own independently focusable children,
  selecting `parts` opens the existing part collector immediately when no
  direct child exists, and otherwise opens one read-only child summary before
  reusing ordinary add, order, show, and typed child-update routes. Merely
  opening, inspecting, or leaving either view records nothing. A batch that
  reclassifies an incapable Brick into child-owning Work requires at least two
  drafted parts; adding to any already compatible Nature requires at least
  one, even when it has no existing child. Acceptance creates the complete
  batch and its handles atomically, preserves every existing child and
  unrelated parent fact, and places the batch under IMP-045. A matching
  duplicate suspicion follows FED-015..016 before commit
  and never merges silently. A newly active child invalidates an already
  pending `scope_closure_review` exactly as FOC-039 requires, with the changed
  review count visible in the result. If the parent is current focus, focus
  and WIP remain unchanged; the preview and result say so rather than
  fabricating staleness or silently clearing attention. Incompatible Natures
  continue through WRK-112 before collection or mutation. A parent covered by
  active `whole_scope` Delegation makes the preview state that each new child
  is covered immediately and will not enter human execution.
- **WRK-116 [core] — Reclassifying a proposed parent is a two-subject atomic
  move.** If an otherwise eligible proposed parent lacks the child-parts
  capability in MOD-062, the finite/open distinction, target-required
  configuration, and every supported MOD-059 reconciliation apply to that
  parent, not to the moving child. No combined confirmation exists while a
  required reconciliation has no defined choice. The final preview leads with
  the parent's complete behavior change, then shows the child movement, and
  lastly composes the ordinary equal- or unequal-Domain facts for the moving
  child. Acceptance revalidates both Bricks, both Nature snapshots, move
  eligibility, reconciliations, direct Domains, focus/WIP, and pending scope
  reviews, then changes parent Nature and composition atomically. A focused or
  WIP parent is never cleared silently; any supported consequence appears in
  the same preview. Rejection changes neither subject and restores the parent
  selector with its query. A released recurring-obligation occurrence follows
  its own validated Brick Nature through the ordinary route; its standing
  series is not the reclassification subject. The two-subject command uses
  UX-198 atomic `batch` compensation over `value` and `structure` members.
- **WRK-117 [standard] — List-item structure reuses one owner surface.** On a
  Nature that owns ListEntries, selecting `list items` enters the collector
  immediately when none exists and otherwise opens the ordinary checklist
  manager. The collector accepts one or more MOD-063 lines, preserves its
  multiline draft through reverse navigation or crash recovery, exposes every
  parsed field and duplicate suspicion before commit, and commits one batch
  atomically. One entry is sufficient even when the accepted batch also
  reclassifies the owner: unlike breaking Work into parts, a one-item list is
  already a meaningful execution unit and does not claim decomposition.

  On an incompatible Nature, WRK-112 first asks only whether the list remains
  available after the current entries close, resolves every target builder and
  reconciliation, then reaches the collector and one combined
  Nature-plus-entry preview. Child Bricks and ListEntries never convert into
  one another. The manager operates on the selected owner and its local
  entries; every contextual palette mutation must resolve and display that
  target explicitly rather than treating the multi-row surface as an implicit
  global reference. An owner covered by active `whole_scope` Delegation makes
  the batch preview state that every new entry is covered immediately and will
  not create human execution.
- **WRK-118 [standard] — Checklist runs preserve honest item and owner
  outcomes.** Accepting a checklist Focus proposal starts or resumes at most
  one active run correlation for that owner. The run ends only through an
  explicit finish; switching focus, pausing, crossing a stale-focus boundary,
  or restarting the REPL preserves it through the ordinary WIP and checkpoint
  rules. Each entry mutation is committed immediately and survives a crash.
  Rows keep their run-local position after resolution or cancellation until
  the run ends, preventing later key presses from targeting a shifted row.

  Finishing after at least one committed entry mutation records resolved,
  cancelled, and still-open counts, clears current focus, applies the ordinary
  standing-run cooldown, and carries every unresolved identity forward. A
  zero-change run cannot be finished as fictitious work; pause, skip, and
  reverse navigation remain available. A `living_checklist_run` never retires
  its owner; zero open entries derive dormancy. A `finite_checklist_run` with
  remaining open entries leaves its owner active after cooldown. With none, it
  finishes the run and immediately enters the existing
  `scope_closure_review`; leaving that continuation preserves the weighted
  review for later. Completion remains a separate explicit action and may be
  chosen even when all entries were cancelled, but the screen must disclose
  that fact and never infer completion from cancellation.

  One entry resolution, cancellation, reopen, or edit; one added batch; one
  run finish; and one checklist completion are separate semantic undo
  boundaries. They use UX-198 `relationship`, `batch`, and `work_state`
  compensation as applicable; undoing a run finish never silently reopens its
  item mutations.

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
  the same advancement through CLI-only `lant tick`, without drawing,
  presenting an opportunity, or inventing other work.
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
- **WRK-146 [standard] — Notices are derived, bounded, and safe-boundary
  only.** Notice candidates derive from a revisioned `best_before` or
  `deadline`, a newly released recurring-obligation occurrence, or a completed
  temporal transition that explicitly declares a notice. `not_before` opening
  changes eligibility without a default notification. At a safe screen
  boundary, the REPL may render at most one discreet candidate plus the count
  of remaining candidates; it never replaces active input, a confirmation, a
  contradiction gate, or scheduled-commitment precedence. Candidate identity
  includes subject, temporal fact revision, notice kind, and threshold, so a
  redraw is stable while a later threshold or edited date is a new notice.
  When several equal-severity candidates exist, a replay-recorded round-robin
  cursor advances only on a real screen transition and prevents one warning
  from monopolizing the footer.
- **WRK-147 [core] — Notice actions change notice state only.** Opening a
  notice offers open Work, acknowledge this notice, snooze this notice, and
  uncertainty. Acknowledgment permanently hides only that exact notice
  identity. Snooze stores a `notice_not_before` instant chosen through
  UX-DT00..DT02; it never edits the Brick's `not_before`, `best_before`, or
  `deadline`. Open Work inspects or proposes the existing subject without
  starting it. Acknowledging or snoozing never changes importance, occurrence
  debt, commitment outcome, or forecast pressure from the underlying date.
  `/notices` lists all current and snoozed candidates with their exact state.
- **WRK-148 [standard] — Recurring obligations use a closed calendar rule.** A
  series stores a positive interval and exactly one frequency family:
  `daily`, `weekly`, `monthly`, or `yearly`; a named IANA zone; and one or more
  local clock times. It also selects occurrence Nature `atomic_task` or
  `scheduled_commitment`. A scheduled occurrence requires one positive
  duration and may retain distinct start/end display zones; an atomic
  occurrence has no duration. Weekly rules also store a nonempty weekday set,
  monthly rules one intended day 1..31, and yearly rules one intended
  month/day.
  Month-end clamping follows WRK-039 without drift. Each nominal anchor also
  has explicit signed offsets for occurrence `not_before` and optional
  `best_before` and `deadline`; no due meaning is inferred from frequency.
  Unsupported cron/RRULE shapes remain source material or require an explicit
  finite expansion rather than approximate core recurrence.
- **WRK-149 [core] — Occurrence release is idempotent and keeps debt.** At each
  canonical tick, every nominal anchor whose occurrence `not_before` has
  opened produces exactly one Brick of the series' declared occurrence Nature,
  keyed by series UUID and nominal anchor. It receives a normal UUID and `#`
  handle, retains the series title, and displays a separate occurrence label;
  repeated titles are valid. An atomic occurrence receives the anchor's
  temporal facts. A scheduled occurrence receives the exact anchor start and
  end and follows WRK-151..156, including attended/missed/cancelled truth and
  hard precedence. Both carry an `occurrence_of` edge, series provenance,
  effective direct Domains, and no independent human importance slot under
  IMP-057. A later anchor never closes an older one. A Nature-owned outcome or
  explicit archive resolves only that occurrence. Schedule edits affect future
  unreleased anchors; already released occurrences retain their facts unless
  an explicit reviewed batch edits them.
- **WRK-150 [core] — Catch-up release is bounded, not lossy.** Offline time may
  open many obligation anchors. One command materializes at most the configured
  release-batch limit in nominal order, records the continuation cursor, and
  completes further batches on subsequent ticks or startup replay before
  claiming catch-up complete. No anchor is coalesced, skipped, or marked done.
  The default limit is 1,000. The startup splash reports real replay/materialize
  progress and useful-empty recovery remains unavailable while a required
  catch-up continuation is pending.
- **WRK-151 [core] — Scheduled commitment data is one exact interval.** A
  `scheduled_commitment` requires `starts_at` and `ends_at` exact instants with
  `ends_at > starts_at`. Each endpoint retains its own display IANA zone, so a
  flight may depart and arrive in different zones. The interval also retains
  provenance and may link Place, ExternalEntity participants, booking Raw
  material, and a source binding through their existing typed relationships.
  A point event requires an explicitly reviewed end or duration. An all-day
  civil event is not this Nature until exact endpoints are supplied. Neither
  workday nor habit-day boundaries reinterpret the interval.
- **WRK-152 [core] — Commitment attention has three truthful outcomes.** At or
  after start and before resolution, the commitment is hard precedence at each
  safe interaction boundary. UX-SC02 can start attention with `attend now` or
  record `cancelled`; it may record `missed` early only through explicit
  outcome review. While current, UX-SC03 offers `attended`, `missed`,
  `cancelled`, and uncertainty—never generic done or skip. After end, UX-SC03
  asks the same outcomes without claiming what happened. Attended closes as
  `done`; missed and cancelled use MOD-089. Every result closes any commitment
  focus/WIP and preserves preparation history. Nothing infers an outcome from
  time, location, calendar absence, or REPL inactivity.
- **WRK-153 [core] — Hard precedence does not silently steal focus.** When a
  commitment opens while ordinary Work is current, the active commitment
  screen names that focus. Choosing `attend now` atomically leaves the old
  Brick WIP and focuses the commitment; inspecting, exiting, or uncertainty
  leaves the old focus unchanged even though the next safe boundary will still
  surface the unresolved commitment. When two or more commitments overlap,
  UX-SC04 lists every active unresolved interval in start-time order and asks
  which to handle; there is no default and no lottery. Resolving one returns to
  the remaining hard-precedence set. A known overlap at creation or reschedule
  requires an explicit keep-both, edit-interval, or cancel choice but remains
  legal.
- **WRK-154 [core] — Anchor changes preview every preparation consequence.**
  Rescheduling recomputes only still-relative constraints on active pending
  preparation Bricks. Completed children retain their historical effective
  instants; manually absolute constraints and explicit overrides remain
  unchanged and are listed as such. The preview reports each old/new instant,
  newly opened or future-gated child, passed best-before/deadline, Dependency,
  and focus/WIP consequence. A focused/WIP child moved behind a future
  `not_before` requires choosing an absolute override or closing focus/WIP in
  the same batch. If the new commitment interval has already ended, attended,
  missed, or cancelled must be selected before acceptance. The anchor edit,
  relative recalculations, chosen overrides, and focus effects commit atomically
  or not at all; dry-run and semantic undo use the same complete batch.
- **WRK-155 [standard] — Anchored attendance is not delegated in 1.0.** A
  `scheduled_commitment` owner has Delegation scope `disabled`. Preparation
  children remain ordinary Bricks and may be delegated independently under
  their own Natures. The disabled route explains that Little Ant cannot infer
  whether another person's attendance would fulfill the same external
  commitment and offers the preparation-child selector when applicable. No
  handoff suppresses active commitment precedence.
- **WRK-156 [standard] — Template preparation is an editable proposal.** The
  offline `flight`, `appointment`, `meeting`, `exam`, and `service_window`
  Templates may propose their catalogued preparation children and relative
  offsets. Before creation, UX-SC01 lists every child, Nature, Dependency, and
  temporal meaning; no item exists until one batch is accepted. Powered-up or
  Skill may omit inapplicable proposals or suggest values with attribution,
  but dumb mode exposes the same editable structure. Template provenance has
  no runtime authority after creation; WRK-154 alone governs later anchor
  changes.

## Standing work and recurrence

- **WRK-019 [standard] — Standing execution.** Finishing one run of a standing
  Brick records an execution outcome, clears focus/WIP as applicable, and
  leaves the standing responsibility active.
- **WRK-020 [standard] — Living checklist.** All open entries render
  through one focus unit and checklist surface, with bounded deterministic
  scrolling and exact counts permitted for large sets. Bought or resolved
  entries leave the next fresh open view but remain in history; during an
  active run they stay visibly closed in their stable row until the run ends.
  Unresolved entries remain. Empty state is dormant, not done.
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
  enabling Brick, pause, archive, or gather more evidence.
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
  an unresolved occurrence is debt, not a missed historical cell. UX-079 and
  UX-H00 define the exact accessible compact forms.
- **WRK-139 [core] — Public focus and standing commands are semantic, not
  aliases.** REPL commands are `/focus #brick`, `/pause`,
  `/return-to-idle #brick`, `/done #brick`, `/finish #brick`, and
  `/archive #brick`. Their CLI counterparts use the same hyphenated action
  names after `lant`. `/focus` starts idle Work or resumes WIP through the same
  focus transition. `/pause` requires current focus and leaves it WIP.
  `/return-to-idle` clears WIP and any focus on that Brick without claiming an
  outcome. `/done` dispatches by the current execution variant under WRK-123.
  `/finish` exists only for an active checklist run, which may honestly retain
  open entries. `/archive` is the only retirement command for a standing
  Brick. The core defines no `/resume`, `/stop`, `/retire`, `/complete`, or
  Nature-specific alias; operators may map natural language to these commands.
- **WRK-140 [core] — Done never retires a standing identity by accident.** For
  finite Work and a recurring-obligation occurrence, `/done` records that
  finite unit done. For a repeatable run it records the run complete and enters
  UX-REP00. For an applicable habit opportunity it records that opportunity
  done and leaves the habit active. Living-checklist completion uses `/finish`
  because unresolved entries may remain; finite-checklist finish may release
  its separate scope-closure review. A standing owner can become terminal only
  through its explicit `/archive` lifecycle preview.
- **WRK-141 [standard] — Repeatable completion chooses one return policy.** A
  completed run closes focus/WIP and appends history before selecting its next
  availability in the same recoverable interaction. With an existing policy,
  UX-REP00 visibly defaults to keeping it; without one, no row is selected.
  The choices are keep/change a completion-relative return, make the Brick
  manual-only, or archive it. A return policy schedules the same identity
  behind one calculated `not_before`; manual-only keeps the active standing
  Brick out of ordinary draws until explicit `/focus`. Archive uses MOD-088.
  Leaving before the policy decision preserves a pending completion-result
  checkpoint and never makes the just-completed run immediately eligible.
  `/focus`, `/next`, and startup restore that checkpoint before another run can
  begin; archive and semantic undo remain available from its palette.
- **WRK-142 [standard] — A return policy is small structured data.** The
  factory forms are `after_completion` with a positive integer center, one of
  `days | weeks | months | years`, and an optional nonnegative symmetric
  variation in the same unit, plus a named IANA zone; or `manual_only`.
  Variation cannot exceed the center. Exact return uses variation zero. At run
  completion, WRK-022 draws one replay-deterministic uniform integer from the
  inclusive `center - variation` through `center + variation` range and
  records both offset and absolute `not_before`; later completions draw again
  from the same versioned policy. Calendar-month and calendar-year arithmetic
  starts from that completion's local civil date and clock time, clamps to the
  last valid day without drift, and resolves the result in the policy zone.
  The dumb editor uses structured fields, not free-form recurrence prose.
- **WRK-143 [core] — The canonical unmet habit outcome is `unfulfilled`.** It
  means an applicable habit opportunity ended without completion. Human copy
  says `not completed in this window`; it never says failure, abandonment,
  overdue, or generic `not done`, which could be confused with an opportunity
  that is still open. `blocked`, `paused`, and `inapplicable` remain distinct
  non-failure window dispositions under WRK-025 and do not break a streak.
- **WRK-144 [standard] — Habit quota outcomes match the missing count.** A
  fixed slot yields one `done` or `unfulfilled` outcome. A quota-window
  completion records one done unit until its target is met. Skip during the
  open window records no unit outcome; at the boundary, an applicable unmet
  quota records exactly the remaining number of `unfulfilled` units. A window
  made blocked, paused, or inapplicable records that disposition for its
  remaining units instead. Expiry is deterministic temporal advancement and
  cannot pause for confirmation; an explicit action that would record
  `unfulfilled` first shows UX-P01 when it would end a visible streak.
- **WRK-145 [standard] — Habit introspection is help, not punishment.** The
  factory profile begins with three consecutive applicable `unfulfilled`
  outcomes or three explicit habit skips across the two most recent applicable
  schedule windows as the lazy review threshold. One
  `habit_introspection_review` then offers inspect
  reasons, adjust the schedule, add enabling Work or a Dependency, pause the
  habit, archive it, or keep it unchanged. It never creates a cause or remedy,
  resets history, awards points, shames the human, or blocks ordinary Work.
  A repeated pattern such as cold weather may support an attributed schedule
  proposal, but the dumb route only exposes the existing typed managers.
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
  valid `archive` or `supersede` routes. Mixed child outcomes follow WRK-130.
  For the `list_entries` purpose, the same transition
  family reports resolved and cancelled counts separately; `add more work`
  opens the ListEntry collector, and a committed open entry invalidates the
  review. Deferral keeps the zero-open finite checklist non-executable until
  this review is served again. An explicit completion is allowed after a
  cancelled-only scope but never inferred or preselected from that evidence.
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

  `whole_scope` derivatively covers current and future descendants,
  Nature-owned entries, and occurrences released by a standing recurring
  series. `brick_only` covers every execution of the selected durable Brick
  identity but none of those related identities. `ask` stores one concrete
  valid choice; two mechanically identical choices must never be shown.
  `disabled` still permits separate enabling work.

- **WRK-032 [standard] — Factory delegation scopes.**

  | Nature | Scope |
  |---|---|
  | `atomic_task` | `brick_only` |
  | `project` | `ask` |
  | `collection` | `brick_only` |
  | `repeatable` | `brick_only` |
  | `living_checklist` | `whole_scope` |
  | `finite_checklist` | `whole_scope` |
  | `recurring_obligation` | `whole_scope` |
  | `habit` | `disabled` |
  | `scheduled_commitment` | `disabled`; preparation children remain independently delegable |

  The two disabled Natures give distinct educational recoveries: habit points
  to enabling Work, while scheduled commitment points to ordinary preparation
  children under WRK-155.

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
- **WRK-119 [standard] — Responsibility builds one proposed Delegation.** Plan
  responsibility first asks whether the human or someone else should do the
  selected Work. Human responsibility is an educational no-op when no active
  or proposed Delegation exists, cancels a proposed one through its preview,
  and enters take-back reconciliation for an active one. `someone else`
  creates a new builder only without overlapping coverage; on a proposed or
  active record it enters edit or reassignment instead. It resolves one
  ExternalEntity through UX-075, then collects, in order: only a mechanically
  meaningful Nature-aware scope choice; mandatory follow-up policy; positive
  review delay; available delivery adapter or manual handoff; and editable
  initial message. A disabled Nature stops with a concrete enabling-Work
  route. `scheduled_commitment` follows WRK-155's explicit educational stop
  and may select preparation children instead; no attendance handoff is
  inferred.

  The complete preview names Work, target, scope, policy, review delay,
  handoff method, and message. Its sole yes creates one MOD-064 `proposed`
  Delegation; everything before yes is a checkpointed InteractionEnvelope
  draft and no Delegation identity or eligibility change exists. After yes,
  those accepted facts and provenance belong to the Delegation and any
  surface may resume it. Stale edits use the ordinary revision conflict. A
  proposed Delegation may be cancelled before handoff without an outbound
  message, because no external responsibility has yet been observed.
- **WRK-120 [standard] — Delegation cadence begins from evidence, not draft
  time.** Every Delegation stores one positive review delay. The factory
  default is 72 hours and dumb alternatives are 24 hours, 72 hours, 168 hours,
  or a positive custom integer number of hours, days, or weeks. The first
  `review_not_before` is derived from the observed initial handoff. A delivered
  follow-up derives it from that handoff; a progress or no-response review
  without another handoff derives it from the review outcome. Typed review
  skip keeps the current facts and applies the configured 24-hour Delegation
  review cooldown without authorizing a message.

  The factory message catalog has four deterministic English patterns:
  initial `brick_only`, initial `whole_scope`, follow-up, and active take-back.
  Each includes the complete rendered Brick reference and declared recipient
  name, is editable and attributed under UX-077, and is never sent
  automatically. `delegation_delivery` and optional
  `delegation_take_back_notice` are distinct approval-bearing external-effect
  purposes; a delivery adapter may implement them only through the ordinary
  effect boundary. Missing contact or credential bindings are not errors and
  leave manual handoff fully available.
- **WRK-121 [standard] — Delegation review separates reports, effects, and
  responsibility.** An internal status review records exactly one human-
  attributed observation: progress, reported completion, refusal, or no
  response; or enters explicit take-back without fabricating an observation.
  Progress schedules the next internal review and may attach separately fed
  Raw evidence. No response proposes a follow-up effect only when policy and
  soft cap permit it; otherwise it schedules the next internal review or opens
  UX-D01. The proposal still needs complete effect approval and observed
  delivery. Refusal and reported completion leave the Delegation active until
  their reconciliation commits, preserving truthful coverage while the human
  decides.

  Reported completion enters existing Nature-owned item, child, occurrence,
  or Brick closure routes. The Delegation becomes `completed` only in a
  combined preview after its exact coverage has valid closure facts; it never
  marks descendants or a parent done by report alone. Refusal offers take
  back, reassign, an explicit existing archive/supersede route for Work that no
  longer matters, or typed review deferral. Take-back rejects every approved
  but undelivered Delegation effect in the same preview, terminates the record
  as `taken_back`, and restores human eligibility before any optional,
  separately approved notice. Reassignment atomically terminates the old
  record as `reassigned`, rejects its stale pending effects, and creates one
  editable `proposed` Delegation for a new target; execution remains human-
  eligible until the new handoff is observed. Archiving or superseding the
  Work closes the Delegation as `cancelled` only with that separately previewed
  Work mutation. No terminal route creates or resolves a Wait.

  Proposal creation, each effect approval, observed handoff, each observation,
  and each reconciliation or terminal transition are distinct semantic undo
  boundaries. UX-198 `gate_responsibility`, `external_effect`, and atomic
  `batch` classes own their exact compensation. Adding a child or entry under
  active `whole_scope` coverage
  discloses before commit that it will already be delegated and excluded from
  human execution. A system-released recurring occurrence receives the same
  derived coverage and names it in the release result and history rather than
  inventing a human confirmation for scheduled generation.

- **WRK-122 [core] — Reclassification resolves one incompatible fact at a
  time.** After target configuration, the dumb surface visits incompatible
  active facts in this deterministic order: an active anchored interval,
  current focus or WIP, an open habit opportunity, open generated
  occurrences, child Bricks, ListEntries, then relative preparation timing.
  It skips absent categories and never asks about compatible state. Each step
  reuses an existing truthful operation rather than inventing a generic
  `discard`: settle the scheduled outcome; disclose closing invalid focus and
  WIP; record the habit outcome; resolve an occurrence or adopt it as ordinary
  independent Work; move child Bricks; resolve or cancel ListEntries; and
  convert a relative constraint to its displayed absolute instant or remove
  it. An active scheduled interval is an educational stop until its real
  outcome exists. A builder may be left and resumed without committing any
  partial disposition.

  UX-NAT01 renders only the current category and progress, then the final
  UX-S47 preview enumerates every accepted choice together. Powered-up and
  Skill may propose the same choices with attribution, but cannot hide a
  category, answer it from prose alone, add a conversion, or bypass the final
  confirmation. If no valid disposition exists, the behavior remains
  unchanged and the result names the exact fact and useful manager to open.

- **WRK-123 [core] — Served-work diagnosis is uniform; completion is
  Nature-owned.** UX-S01 uses the same symptom names and order for all five
  ordinary execution variants in FOC-037. No Nature gets a private diagnostic
  screen, and no symptom is hidden merely because its eventual recovery may
  require reclassification. The `Already finished?` action dispatches to the
  truthful execution outcome: `finite_work` completes its finite Brick;
  `repeatable_run` finishes this run and enters the existing finish-or-return
  choice; `habit_window` records this opportunity as `done`; and either
  checklist variant opens its owner surface to reconcile open entries before
  finishing the run. It never marks unseen checklist entries done in bulk.
  When every finite-checklist entry is already closed, run finish releases the
  ordinary scope-closure review. Scheduled commitments do not use UX-S01 and
  retain their anchored outcome screen.

  Every other recovery remains available through its established semantic
  preconditions. In particular, `big` may enter MOD-077..081 reclassification
  from any Nature; if active state makes the requested change unavailable, the
  surface explains that exact fact and returns to the unchanged `collect more
  context`, `learn`, `skip anyway`, and back routes. It does not silently
  replace decomposition with a different remedy.
- **WRK-124 [core] — Defer-only aftermath follows the served execution
  variant.** A final reaction that applies an ordinary cooldown closes the
  focus interval only when the served Brick was current; declining an
  unstarted Focus proposal creates no WIP. Finite Work, repeatable runs, and
  active checklist runs remain active and, if they had started, WIP. Checklist
  entries and run state are untouched. A fixed-slot habit skip settles the
  opportunity under WRK-063 and returns its standing owner to idle; a
  quota-window skip closes current attention but leaves the still-achievable
  window and any existing WIP honest. Released recurring-obligation
  occurrences behave as finite Work and remain open debt. Recovery-specific
  Dependency, Wait, Place, Domain, or pause consequences continue to replace
  this default wherever their accepted rule says so. No branch changes
  importance or fabricates progress.
- **WRK-125 [core] — No easier candidate becomes a useful reaction, not an
  empty list.** When FOC-044 finds no other executable Work, UX-S08E states
  that fact before `tired` has committed and offers `change subject`,
  `organize and review` when eligible, `pause for now`, `skip anyway`, back,
  and uncertainty. Each selected route reuses WRK-070, WRK-075, WRK-071, or
  WRK-047 respectively. If a downstream subject or organization route also
  has no target, its existing useful-empty result returns here without
  fabricating a candidate or recording two reactions.
- **WRK-126 [standard] — A custom short sprint stays short and structured.**
  UX-S15A accepts one whole number of minutes from 1 through 120. It accepts
  digits only, shows the resulting end instant before starting, and returns a
  typed correction for zero, fractions, units, natural language, or a value
  above 120. The factory still recommends the visible 5, 15, and 25-minute
  choices; custom input adds no learned duration and uses the same WRK-078
  focus-consent boundary.
- **WRK-127 [core] — One absolute date/time chooser serves deferral.** Every
  `later`, Wait-review custom choice, and other ordinary instant builder uses
  UX-DT00..DT02. The caller supplies honest visible presets and one suggested
  clock time, but the accepted value is always one unambiguous absolute
  instant plus its named IANA zone. Dumb custom input is structured
  `YYYY-MM-DD`, then `HH:MM`; it accepts no natural-language date parser. A
  later-style date suggests that profile's workday start. A Wait-review date
  suggests the current local wall-clock minute. The user may change the clock
  time or zone before final confirmation. Relative presets preserve the local
  wall-clock time across civil dates, show the complete resulting local date
  and time before selection, and resolve gaps or repeated clocks explicitly
  under WRK-042. Reverse navigation commits nothing.
- **WRK-128 [core] — Remaining update purposes dispatch to small typed
  managers.** Timing offers only the applicable subset of `may start`,
  `preferred by`, `deadline`, `repetition`, and `commitment interval`.
  Context offers `Domains`, `people or companies`, and `location`. Source material offers
  `linked Raw material` and `external origin`. Each
  row invokes its already typed relationship, temporal, RawLink, or
  SourceBinding manager and one-change preview. Inapplicable rows are omitted
  with no disabled clutter; if none apply, the screen explains why and returns
  to UX-S37. Description remains under meaning; parent, parts, blockers, and
  responsibility remain under plan; supersession remains its explicit
  lifecycle route. These screens create no generic metadata or relationship
  editor.
- **WRK-129 [core] — Lifecycle changes reconcile live gates before scope.**
  Archiving or superseding a focused Brick closes its focus interval and
  clears WIP in the accepted preview. An active scheduled interval first needs
  its truthful attended, missed, or cancelled outcome. An active habit window,
  recurring series, or open occurrence follows MOD-080's existing settlement
  choices. Waits owned only by retiring Work may be explicitly cancelled as
  no longer awaited; a response is never inferred. Active Delegation coverage
  must be taken back, reassigned, narrowed outside the retiring scope, or
  cancelled through the same preview and any required effect approval.
  Approved but undelivered effects are explicitly rejected or reissued;
  dispatched receipts remain history.

  An outgoing Dependency wholly inside an archived subtree becomes inactive
  with that scope. When active Work outside the retiring scope depends on a
  retiring Brick, every such edge must be retargeted to valid replacement
  Work, removed with explicit disclosure that the dependent may become
  executable, or the dependent must enter its own archive/supersede preview.
  The core never leaves an active dependent behind an impossible terminal
  prerequisite or rewrites importance to compensate.
- **WRK-130 [core] — Scope closure reports how the children ended.** A
  `scope_closure_review` released by MOD-083 renders done, archived,
  superseded, merged, missed, and cancelled direct-child counts separately.
  `complete the parent`
  is available even when some children were not done, because it is a fresh
  human judgment about the parent outcome, but it is never preselected from
  cancelled or non-done evidence. `review outcomes` opens the bounded child
  list; `add more work` and typed review skip keep WRK-066 semantics. Any
  restored or newly active child invalidates the review before acceptance.
- **WRK-131 [core] — Merge resolves matrix conflicts before identity loss.**
  `lant merge` or a durable duplicate review selects exactly two different
  Bricks and one survivor, then walks only the `choose` cells in MOD-086.
  Conflict order is lifecycle/Nature, parent/structure, description, temporal
  and recurrence state, Dependencies and Waits, Delegation/effects, then
  source identity. Each choice is a resumable draft. UX-LC02 renders the full
  transfer matrix with counts and exact exceptions before the sole commit.
  Acceptance marks the loser `merged`, records lineage, and updates only the
  relationships declared by MOD-086. Keep separate records only the duplicate
  review outcome, not negative global equivalence.
- **WRK-132 [core] — Supersession starts from replacement responsibility.**
  `lant supersede` identifies old Work and selects or drafts the replacement.
  The old and replacement remain different identities. When the old Brick has
  children, UX-LC03 asks whether the replacement covers those parts or the
  parts should move one level up; an incapable replacement enters the ordinary
  Nature reconciliation and may be rejected without side effects. The builder
  then visits only live gates and explicit optional transfers from MOD-087.
  The final preview leads with `Old Work becomes superseded by` and never says
  merge, duplicate, copy everything, or done.
- **WRK-133 [standard] — Lifecycle commands stay explicit and searchable.**
  CLI commands are `lant archive #brick`, `lant supersede #old #replacement`,
  and `lant merge #survivor #absorbed`, all with `--dry-run`. In the REPL,
  `/archive`, `/supersede`, and `/merge` use typed `#` autocomplete and guided
  missing arguments; they accept no reversed natural-language alias or hidden
  current target. Contextual palette entries may prefill the one unambiguous
  displayed Brick but still render the complete resolved citation. Restore is
  the independent `/restore #brick`; merged and superseded Bricks cannot be
  restored as active through archive restoration.

## Place context

- **WRK-035 [standard] — Place conditions.** A Brick may have zero or more
  `required` or `preferred` PlaceConditions. A condition is a canonical
  English nonempty place label plus its kind; it is not a Place entity, handle,
  Domain, hierarchy, ExternalEntity, or world-object registry. Labels used
  before may be suggested by autocomplete, but selecting or typing one stores
  the value directly on this condition and creates no global record.
- **WRK-036 [standard] — Attributed observations.** Current location is an
  attributed observation from a human or adapter. An adapter observation has
  exact `observed_at` and `valid_until` instants and one or more matching place
  labels. The one-screen human confirmation in WRK-159 is valid only for that
  pending Focus proposal and creates no lasting location claim. Location
  affects eligibility or chance only within its declared strength and
  validity.
- **WRK-037 [standard] — Privacy boundary.** Adapters provide observations;
  the core does not continuously track location or silently perform external
  actions.
- **WRK-157 [standard] — Required means confirm before focus.** A required
  PlaceCondition does not remove its Brick's attention subject from the
  positive-tail draw. After the subject and executable Work endpoint are
  selected, a valid matching observation proceeds normally. Otherwise the
  core returns the `place_confirmation` continuation in FOC-063 instead of
  pretending the Work is currently executable. Required labels are OR choices:
  matching any one is enough. A Brick that truly requires several places at
  once must use one honest combined label rather than an unsupported Boolean
  expression.
- **WRK-158 [standard] — Preferred is a bounded hint.** A valid matching
  observation may add one bounded forecast signal for a preferred condition;
  a known nonmatch may add a bounded negative signal; missing or expired
  observation is neutral. Multiple matching preferred labels use the strongest
  signal and never multiply tickets. Preferred place cannot exclude Work,
  reorder importance, or become a deadline.
- **WRK-159 [standard] — Human place answer is local to one proposal.** On
  UX-PL01, `yes` records an attributed one-proposal confirmation and continues
  to the already selected Work's ordinary `Focus?` without another draw. `no`
  records only a replay-stable place deferral and configured cooldown for that
  Brick, then returns to `next`; it is not a served-work skip, Wait,
  `not_before`, active Domain change, or persistent claim that the human is
  elsewhere. Uncertainty remains in the same bounded confirmation route.
- **WRK-160 [standard] — Place maintenance is one small manager.** The
  blocked-or-waiting `location` route creates one required condition. Context
  maintenance can add required or preferred conditions and remove one existing
  condition. Every change shows the Brick, label, kind, and resulting focus
  consequence in one preview; no free-form Boolean rules or background
  geofences exist in 1.0.

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
  opportunity records one discrete outcome: `done` or WRK-143's canonical
  `unfulfilled`. The 1.0 core does not add
  generic target quantity, unit, observed value, or percentage-progress fields
  for habits. A desired amount such as pages, minutes, distance, or repetitions
  may remain in the title, description, completion criterion, or optional
  execution note without changing the outcome model.

# 18. Confirmed invariants at a glance

1. Every active Brick has one parent scope and one sibling position from birth.
2. Every active sibling set has a strict total priority order.
3. Priority asks whether one sibling is more important than another; it is not
   urgency, dependency, maturity, effort, or execution sequence.
4. Priority comparisons are valid only between siblings.
5. Global priority display is lexicographic by tree path.
6. Dependencies affect eligibility and pressure, never human priority position.
7. Phase is optional, Nature-applicable, and never sorts importance.
8. Human judgments prevail over AI judgments.
9. All judgment history is retained; current judgment favors newer applicable
   evidence within authority rules.
10. Contradictions lower confidence or reliability and trigger local
    validation or recalibration rather than invalidating state.
11. Raw is material, never directly prioritized or focused.
12. Raw use is non-consuming and many-to-many.
13. A ListEntry is neither Raw nor a Brick; it is resolved inside its owning
    batch and has no independent priority, phase, effort, or `next` eligibility.
14. Persisted entity identity is opaque and independent from titles.
15. Duplicate titles are allowed. Duplicate suspicion is scoped evidence and
    never silently merges, deletes, or discards input.
16. Content hashes deduplicate immutable bytes, not semantic entities or
    provenance.
17. Canonical searchable product data is English; verbatim original input may
    be retained separately as Raw or provenance.
18. Multiple WIPs may exist; current human focus is zero-or-one.
19. Finishing one execution of standing work does not terminally complete the
    standing Brick.
20. Forecast is derived and read-only; `next` records a reproducible draw.
21. Served-Brick skip, ordering skip, classification skip, and
    practice-opportunity skip are distinct core operations.
22. `?` is visible in every finite-choice loop and records neither answer nor
    skip.
23. `tie-break for me` delegates a strict provisional priority direction; it
    never asserts equal importance.
24. Impact means expected impact and uses
    `VERY_LOW < LOW < MEDIUM < HIGH < VERY_HIGH < CRITICAL`.
25. Only roots are directly classified for impact; descendants inherit their
    root assessment.
26. Public impact evidence maturity is
    `SPECULATIVE < SUPPORTED < VALIDATED < OBSERVED`; it is not probability of
    success.
27. Purposeful investigation may be an ordinary Brick, and completing it
    never silently changes the judgment it informs.
28. Effort is optional, Nature-applicable, and means total work for the
    current scope, not remaining work.
29. Effort uses a discrete, ordered, versioned EffortProfile. There is no
    public effort float or global effort list.
30. Progress never lowers total effort. Remaining effort is derived only from
    conservative evidence.
31. Parent effort includes descendant scope. Decomposition coverage must be
    explicitly confirmed and structural changes reopen it.
32. The core may suspect scope change mechanically, but only a human or
    operator confirms a semantic scope revision.
33. Hours never belong to canonical Brick state.
34. A planning cut is non-overlapping, so no plan counts effort at both a
    Brick and its descendant.
35. Every planning-cut item uses one macro that expands into all scenarios.
36. Every confirmed simulation has an immutable reproducible planning manifest
    outside operational domain state.
37. BrickNature selects only explicit, versioned core capabilities.
    BrickTemplate is an inspectable creation recipe and gains no hidden runtime
    authority after expansion.
38. Domain templates never create hard-coded grocery, reading, wishlist, or
    software branches in the core.
39. Standing collections, recurring obligations, and practices have distinct
    recurrence semantics.
40. An unpaid recurring obligation remains open and may become overdue even
    after a later occurrence is released.
41. An applicable practice opportunity may finish as an unfulfilled outcome,
    but it never becomes an infinite overdue backlog.
42. A blocked or explicitly paused practice produces no false unfulfilled
    outcome and no streak loss during the blocked window.
43. Practice strips and streaks are derived from occurrence history, not
    mutable scores.
44. The core may detect repeated outcomes and reasons, but causal
    interpretation and semantic enabling-work proposals belong to a human or
    attributed operator.
45. The core never calls AI or the network for judgment.
46. External actions remain explicit and human-approved.
47. The core has one canonical English vocabulary and no compatibility aliases.
48. The 1.0 REPL, optional powered-up REPL, and operator skill use the same
    state-scoped canonical interaction protocol.
49. Powered-up suggestions remain attributed AI evidence and never gain human
    authority.
50. Finite choices in the REPL execute on one keypress; text entry is an
    explicit mode.
51. REPL recovery state is stored separately from the domain event log, and a
    stale keypress is never applied to a different prompt.
52. There is no generic Artifact entity. Brick description, durable Raw
    material, and behavioral relationships retain separate explicit
    semantics.
53. A Raw has at most one external origin. Mirrors, drafts, forks, and
    published copies are distinct Raw entities connected through provenance.
54. Raw snapshots are immutable and content-addressed; refresh appends a
    version instead of overwriting history.
55. External check, material refresh, and per-Brick reconciliation are
    distinct operations. Divergence is derived from observations, snapshots,
    and each applicable RawLink baseline.
56. External-origin reads and write-backs never occur silently.
57. A repeatable Brick retains one identity, one human priority position, and
    an execution-occurrence history across repeats.
58. Completion-triggered repetition schedules the same active Brick with one
    deterministic, replay-safe, jittered `not_before`; it does not insert the
    Brick again or create another Brick.
59. A generic repeatable activity has no missed outcome, expiry, streak, quota,
    or occurrence backlog unless another explicit Nature adds those
    semantics.
60. Separate occurrence Bricks are required when several periods may remain
    independently unresolved, as with recurring obligations.
61. A collection is an open-ended container of independently focusable child
    Bricks ordered by human importance; it has no FIFO semantics and becomes
    derivatively dormant when empty.
62. A project represents one finite outcome whose descendant scope contributes
    to its completion; a collection does not accumulate completion progress
    toward a parent outcome.
63. The product may ship a broad standard template catalog as versioned,
    inspectable data without creating domain-specific core branches.
64. Dumb REPL, powered-up REPL, and operator skill use the same core-validated
    feeding routes and template candidates. AI ranks proposals but does not
    expand an unvalidated template or invent a Nature capability.
65. A custom template flow reuses an existing Nature when possible and may
    create a personal Nature only from capabilities already supported by the
    core.
66. RawSnapshot bytes are logically part of the Little Ant dataset and
    participate in synchronization and backup by default.
67. A referenced blob that is absent or fails content-hash verification is an
    explicit incomplete or corrupted condition, never a valid metadata-only
    snapshot.
68. The core owns blob identity, integrity, references, and availability, but
    remains independent from Git and every concrete replication or storage
    transport.
69. The core owns one typed canonical status summary shared by CLI, REPL,
    powered-up mode, and operator skill.
70. `la status` uses the compact canonical human rendering by default; no
    separate `--line` alias exists.
71. Structured status consumers use the same typed fields rather than parsing
    or independently recomposing the compact line.
72. Grooming and preparation reviews are interactions or derived proposals,
    never independently prioritized meta-Bricks.
73. A guided Brick review asks only currently applicable, materially useful
    questions and records each accepted result through the corresponding
    ordinary domain operation.
74. If a review discovers real enabling, clarification, or investigation work,
    that work may become an ordinary Brick only through an explicit proposal
    and confirmation.
75. `done` transitions any active Brick directly without requiring phase,
    work state, optional metadata, or fabricated intermediate events.
76. Direct completion still enforces subtree, standing-work, repeatable,
    external-effect, and other applicable Nature invariants.
77. Raw has review and archive axes but no `done` operation.
78. The core never materializes a Brick from Raw merely to make a completion
    command succeed.
79. `already done` is not canonical vocabulary; it is ordinary direct `done`
    without prior start evidence.
80. Direct completion never synthesizes a zero-duration start. Unknown observed
    duration remains unknown.
81. A served Brick exposes `done` separately from start and skip, and
    completion is never encoded as a skip reason.
82. Human-reported and externally proposed completion use the same canonical
    operation but retain different provenance and authority.
83. Stored entity identity never depends on a title, normalized title, or
    matching fingerprint.
84. A human-facing canonical English title receives only conservative Unicode
    and whitespace cleanup. Product-owned emoji remain renderer metadata;
    intentional user content is not silently stripped or semantically
    rewritten.
85. Duplicate matching uses derived, rebuildable fingerprints as ranked
    evidence. A fingerprint never becomes identity, a global alias, or
    authority for a silent merge.
86. Closing the last active child never automatically completes its parent.
87. A finite parent receives `review_parent`; complete decomposition coverage
    plus successful child outcomes strengthens the `done` proposal, while
    incomplete or mixed outcomes require a neutral review.
88. An empty standing collection becomes dormant rather than terminally
    complete.
89. Parent review ascends at most one explicitly confirmed level at a time;
    ancestors never complete automatically in a cascade.
90. An event-trigger rule releases an opportunity on an existing standing
    target; it never creates, resurrects, starts, or completes a Brick.
91. Event-trigger rules accept only explicit canonical source events and
    core-supported release capabilities, never arbitrary scripts or hidden
    template code.
92. Each release is idempotent for its trigger rule and source event.
93. Natural-language reports must first become an attributed canonical source
    event before they can activate the same deterministic trigger path.
94. Semantic continuity of standing work is an explicit human or attributed
    operator judgment; the core never infers it from title or configuration
    similarity.
95. Updating continuing standing work preserves its Brick identity and appends
    configuration history without rewriting past occurrences.
96. Superseded standing work and its successor retain separate occurrence and
    streak histories. Recurrence, triggers, dependencies, and placement never
    transfer silently.
97. Similar input may propose reactivating retired standing work, but duplicate
    suspicion never resurrects it automatically.
98. Location sensing, device permission, raw coordinates, and geofence
    geometry remain outside the deterministic core.
99. A location observation is attributed, idempotent, and time-bounded; stale
    evidence never continues affecting selection.
100. Place conditions and current observations may affect eligibility,
     forecast, and grouping, but never human priority.
101. Manual and adapter observations use the same canonical ingestion path
     while retaining different provenance.
102. Location evidence never authorizes silent start, completion, dependency
     resolution, notification, or another external effect.
103. A literal `@...` token has no canonical target or behavioral authority
     until an explicit typed annotation is confirmed.
104. Typed annotations refer to opaque target identity and one owner-field text
     revision; target renames never break the reference.
105. Ambiguous or unresolved mention text remains literal and never binds
     silently.
106. Text annotations support navigation and search only; requester,
     delegation, dependency, parent, `about`, notification, and other semantics
     require their ordinary explicit relationships.
107. Raw bytes and text are never automatically parsed or rewritten to create
     annotations.
108. The append-only event log is authoritative for operational domain state,
     while every referenced canonical blob is also a required member of the
     logical dataset.
109. A missing or hash-invalid canonical blob is explicit incomplete or
     corrupt state, never a valid database-backed substitute.
110. Operational databases, indexes, caches, and materialized views contain no
     unique canonical state and must be safely rebuildable from authoritative
     data.
111. Domain mutations always pass through canonical core operations and event
     append; no projection provides a bypass write path.
112. REPL checkpoints and planning manifests have bounded non-domain authority
     and never become operational domain projections.
113. A blocked Brick retains its human priority position and may be compared
     with siblings by importance; becoming unblocked changes eligibility
     without another priority insertion.
114. The core interaction envelope owns context-valid actions, canonical
     commands, shortcuts, and help. The operator interprets language, while
     first-party surfaces and UIAdapters render channel-specific affordances
     without redefining domain semantics.
115. Every confirmed semantic answer is recorded through its ordinary
     canonical domain operation; a question round has no deferred batch
     commit.
116. Interrupted probes and reviews resume from current domain state and never
     create a round, continuation, or reminder Brick.
117. Unconfirmed text, cursor position, screen state, and local transcript are
     presentation-checkpoint data and cannot silently mutate canonical domain
     content.
118. A progress denominator is exact only when the remaining set is finite,
     stable for the stated scope, and known. Adaptive interactions expose
     honest facts or labeled estimates instead of fictional percentages.
119. A next prompt may be derived from current state, but pseudo-random prompt
     choices retain the seed, cursor, or selected candidate needed for replay
     and stale-answer validation.
120. Party identity is an opaque immutable ID. Display labels and alternate
     names may change or collide without changing identity or creating global
     aliases.
121. Canonical events reference opaque IDs; human renderers resolve current
     labels and disambiguating context instead of making readable words
     authoritative identifiers.
122. On annotation-capable editing surfaces, `@` opens Party candidates and
     `#` opens Brick candidates. Only explicit selection creates a typed
     annotation to opaque identity.
123. Sigil-shaped text, including `issue #918` or `github:@alice`, remains
     literal when no autocomplete candidate was selected.
124. A URI may be rendered as a clickable literal without creating domain
     authority. External material that needs refresh or reconciliation is
     fed explicitly as Raw with RawOrigin and the applicable RawLink.
125. Provider-specific locators may be normalized inside adapter contracts,
     but they do not form a universal core grammar parsed from arbitrary text.
126. `not_before`, `best_before`, and `deadline` affect eligibility, forecast,
     notices, and planning without rewriting human priority.
127. A meaningful date-threshold crossing creates at most one notice
     occurrence for the Brick, date revision, and threshold; repeated ticks
     do not duplicate it.
128. Acknowledging or snoozing a date notice changes presentation only. It
     never changes the underlying date, eligibility, priority, or forecast
     pressure.
129. An ongoing date condition remains inspectable in status and forecast
     without requiring the same warning to be prepended to every CLI result.
130. External feeding and semantic adoption are separate; a configured
     structured-task source may perform both atomically, while unknown,
     mixed, and note-like sources remain pending Raw for triage.
131. Every automatically adopted Brick is validly positioned from birth.
     Provisional import placement lowers priority confidence and creates
     comparison pressure rather than treating upstream order as human
     importance.
132. Provider, account, and container groups are derived source views, not
     automatic RawShelves. Semantic destinations come only from an explicit
     route or confirmed ImportProfile.
133. Reimport resolves stable external identity to the same Raw and existing
     adoption. Similar content under another identity raises duplicate
     suspicion and is never silently merged.
134. A Little Ant Pack is a versioned distribution unit, not domain
     authority. Declarative components use only core-supported capabilities,
     and executable components declare a distinct trust class and permissions.
135. SourceAdapters and Enrichers submit normalized candidates, observations,
     effect receipts, or attributed proposals through canonical validation.
     Installation never implies write-back or unrestricted access.
136. Structured operational responses are command-specific and sparse by
     default; a complete projection remains explicitly available from the same
     canonical state.
137. Every successful mutator returns a compact typed postcondition sufficient
     to identify the affected state without automatically echoing the complete
     entity.
138. Field omission is defined by the selected schema and projection. Missing
     sparse fields never generically mean null, false, zero, or empty.
139. Meaningful false values, zeros, explicitly requested empty collections,
     selected tri-state values, and explicit clearing outcomes remain visible.
140. Full event payloads are explicit audit data rather than default response
     baggage. Any actionable outcome still appears in the current typed result,
     notice, status, or interaction envelope.
141. External work state and external presence are independent observations.
     Completion evidence and deletion evidence never substitute for one
     another.
142. External deletion never completes, drops, archives, or deletes a local
     Brick, ListEntry, Raw, RawLink, or RawSnapshot.
143. Filter omission, refresh failure, inaccessible credentials or containers,
     and ambiguous provider responses do not prove upstream deletion.
144. Unexpected mass removal pauses automatic reconciliation and produces one
     source-level anomaly rather than many inferred lifecycle changes.
145. Migration cutover is explicit. An empty source or import batch never
     finalizes migration implicitly.
146. Finalized cutover retires the applicable ImportProfile and suppresses its
     ordinary freshness pressure while preserving historical RawOrigins,
     snapshots, mappings, observations, and an immutable migration receipt.
147. Ordinary import is read-only. Source cleanup requires an explicit
     destructive migration policy, a separately declared Adapter capability,
     verified local feeding and disposition, a preview of exact scope, and
     human approval before the first deletion.
148. Migration cleanup is logically item-scoped even when an Adapter batches
     provider calls. Each requested and observed outcome is attributable to
     one stable external identity.
149. Partial cleanup is resumable. Completed imports and deletions are not
     rolled back, unresolved items remain explicit, and the ImportProfile is
     not retired until every selected item has a resolved cleanup disposition.
150. Deleting an emptied external container is a distinct destructive effect
     and is never implied by deleting imported entries.
151. `Little Ant Pack` is the canonical versioned distribution unit.
     Little Ant 1.0 has no generic Plugin entity, command, alias, lifecycle
     hook, or unrestricted extension API.
152. Every PackComponent has one typed versioned contract. Declarative
     components are BrickNature, BrickTemplate, and ImportProfilePreset;
     executable components are SourceAdapter, Enricher, ReadOnlyExporter, and
     UIAdapter.
153. Pack components cannot introduce ranking or forecast algorithms,
     canonical entity or event kinds, storage engines, global commands,
     self-owned schedulers, arbitrary lifecycle hooks, or direct canonical
     mutation.
154. Lua 5.4 is the only first-class executable Pack runtime in 1.0. Every
     executable component, including the standard Pack, runs in a fresh VM in
     a separate HsLua-based `lant-pack-runner` process.
155. Executable Pack invocations have bounded time, instructions, memory,
     output, nesting, and declared host capabilities. They receive no
     unrestricted `io`, `os`, `debug`, raw socket, dynamic C-module, or
     dynamic dependency-installation access.
156. Pack code never executes during domain replay. Accepted candidates,
     observations, proposals, effect receipts, and canonical events preserve
     component version and provenance.
157. Pack HTTP uses the host-owned `lant.http.request` contract. Exact allowed
     hosts are declared, and a redirect to an undeclared host fails
     explicitly.
158. Credentials live in a Little-Ant-owned encrypted local vault with
     separate deployment authority. The vault and CredentialBindings are
     excluded from Packs, domain events, and ordinary dataset synchronization.
159. The CredentialBroker owns authorization, refresh, and request injection.
     Lua names a credential binding but never receives a stored secret or
     access token.
160. A locked vault leaves credential-dependent scheduled work due with an
     explicit `credential_locked` condition; it neither fabricates a provider
     failure nor advances provider backoff.
161. A ReadOnlyExporter receives a versioned core projection and returns
     bounded bytes and export metadata. It has no network, filesystem,
     subprocess, or canonical mutation authority.
162. The standard Pack shipped with 1.0 includes a Lua TaskJuggler
     ReadOnlyExporter as both supported integration and the public reference
     executable component for community authors.
163. TaskJuggler effort semantics, planning cut, projection validation, stable
     IDs, and immutable planning manifest remain core-owned; the Lua exporter
     owns only target-format serialization.
164. UIAdapter is a first-class 1.0 PackComponent. It renders the canonical
     InteractionEnvelope and maps channel input to exactly one canonical
     action ID and the interaction revision against which it was displayed.
165. UIAdapters cannot invent actions, commands, aliases, or shortcuts,
     weaken approvals, mutate canonical state, retain credentials, or turn a
     stale transport reply into a current answer.
166. A configured personal UI surface may deliver ordinary Little Ant
     interaction. Messages to other recipients, publishing, and unrelated
     notifications remain explicit external effects.
167. Every compact human-facing citation of a particular Brick uses
     `#shortid "Canonical English title"`; a containing Brick and a Brick
     mentioned only in an explanation follow the same rule.
168. Dependency blocking alone does not exclude an otherwise admitted active
     Brick from the initial attention draw.
169. If a drawn Brick is blocked, `next` records and follows the finite path
     `B0 -> B1 -> ... -> BN`, where every Brick is blocked by the next and
     `BN` is the actionable result.
170. Effective blocker pressure is derived from attention mass resolved
     through dependency paths, not stored as a separate mutable field.
171. The compact `Next`, `Within`, and `Why` rendering identifies the
     actionable endpoint, relevant container, initially drawn Brick, and
     ordered blocker path; `?` retains access to the complete path.
172. The canonical phase set remains `idea | spec | exec | validation`.
     `design` is not an alias for `spec`, and the abandoned seed glyph `🌱`
     is not a 1.0 phase marker. The canonical `spec` marker is `📐`.
173. At a dependency branch, resolution makes a replay-deterministic weighted
     subdraw in which every admitted immediate blocker has positive chance,
     records the chosen edge, and leaves unchosen blockers unresolved and
     inspectable through `?`.
174. A dependency-branch subdraw reuses the same focus-forecast weighting
     function, evaluated and normalized locally over the admitted immediate
     blockers; the core has no second blocker-specific ranking policy.
175. `next` returns one member of a versioned closed set of core-defined
     focus-opportunity variants. `interaction` is not a public catch-all
     command, and extensions cannot invent variants or canonical actions.
176. A comparison suggestion renders the concrete directional relation as its
     primary prompt and interprets `yes` or `no` against that displayed
     direction.
     Provenance remains structured and available through `?`, but a prominent
     `Why` block is not required when the question is self-explanatory.
177. The REPL is the reference interaction design for Little Ant 1.0. Web,
     mobile, UIAdapters, and the operator skill preserve its domain prompts,
     action semantics, information hierarchy, and progressive disclosure while
     adapting controls and layout to their channel.
178. Canonical response letters keep the same meaning across interaction
     variants and surfaces whenever applicable: `y` confirms the displayed
     proposition, `n` rejects it, `d` completes the cited Brick, `s` skips
     without answering, and `?` requests context or help without answering.
179. The operator skill or powered-up REPL may provide attributed
     low-authority comparison evidence before a placement question reaches the
     user. The core alone validates that evidence and performs provisional
     binary insertion; human evidence remains authoritative.
180. AI-assisted provisional placement may proceed without a blocking
     confirmation, but its provenance remains visible in recap, history, and
     inspection. Dumb mode or an abstaining adapter asks the human through the
     ordinary insertion flow.
181. Every newly selectable focus-opportunity variant participates in the same
     weighted draw. Approval, follow-up, review, question, and executable-work
     kinds receive no deterministic precedence merely because of their type.
182. An already pending interaction or active current focus resumes before a
     new draw because it is a continuation, not a newly selected opportunity.
     A consistency failure that makes a valid draw impossible produces an
     explicit diagnostic and is not a `NextSuggestion`.
183. Pending opportunity counts remain visible in status even when another
     kind wins the draw.
184. Focus forecast is a replay-deterministic hierarchical probability model,
     not a flat array in which every applicable opportunity independently
     competes at the top level.
185. Each admitted attention subject participates once in its applicable
     attention scope regardless of how many opportunity variants currently
     apply to it.
186. After an attention subject is selected, one locally normalized weighted
     subdraw selects among its admitted opportunity variants. Every admitted
     local variant retains positive probability, and variant kind creates no
     fixed precedence lane.
187. A selected project-like container is resolved according to its
     BrickNature through the applicable descendant scope or an explicit
     review or decomposition boundary; descendants are not flattened into
     unrelated top-level tickets.
188. One attention subject's weight is anchored by its strongest applicable
     opportunity signal. Additional independent signals may add only a
     bounded bonus with diminishing returns; opportunity fragmentation cannot
     manufacture additional top-level probability.
189. A Brick may belong to several branches of the hierarchical
     organizational-classification model. Those memberships are orthogonal to
     Brick composition, importance order, Place, mode, and other execution
     conditions.
190. `feed` and `feeding` are the sole canonical product-ingress vocabulary.
     The 1.0 core, Allium declarations, commands, responses, code, and tests
     expose no compatibility alias using the superseded term.
191. Every Brick has exactly one core-validated `BrickNature` from birth. If
     no human, template, skill, or powered-up judgment selects a more specific
     one, the core uses the generic `standard` Nature.
192. Recent accepted focus gives a bounded soft forecast bonus to subjects
     sharing an applicable Domain. Mere display or skip does not establish a
     Domain switch, and multiple shared memberships do not create multiple
     tickets.
193. The active Domain is explicit persisted focus-continuity state. It
     influences forecast softly and is neither human importance nor an
     implicit hard filter.
194. Domain affinity is hierarchical. Its default structural factor is the
     depth of the lowest common ancestor divided by the greater path depth;
     exact membership is strongest, nearby shared ancestry is weaker, and
     unrelated top-level branches receive no continuity bonus.
195. A subject with several Domain memberships uses its strongest applicable
     affinity. Membership overlap contributes one bounded signal inside the
     strongest-signal-plus-bonus model and never manufactures tickets.
196. A cross-Domain draw remains an ordinary `Focus?` interaction with the
     prospective transition visible; it never introduces a preliminary
     `Switch Domain?` confirmation.
197. On that focus interaction, `y` atomically starts focus and changes the
     active Domain, `d` completes directly without changing it, `s` records an
     ordinary served-work skip and preserves it, and `?` explains without
     answering. `n` is omitted because it would duplicate skip.
198. After a cross-Domain skip, the next selection is another global weighted
     draw. Domain continuity still biases that draw, but related and unrelated
     eligible Domains retain positive probability.
199. When the active Domain is an ancestor of an accepted Brick membership,
     focus narrows it to the most specific applicable descendant membership.
     An unrelated additional membership does not prevent that transition.
200. A served-work skip records a symptom, not a remediation action. The first
     skip screen offers several applicable symptoms together; accepted
     reactions belong to a subsequent interaction.
201. The 1.0 candidate skip-symptom inventory removes `meh` and includes
     `fear` in its place. The remaining taxonomy still requires review.
202. A Domain-scoped reaction may apply one short subtree cooldown followed by
     one bounded, replay-deterministic decaying negative forecast signal. It
     never changes human importance.
203. Selecting a symptom alone never silently changes the active Domain,
     chooses the affected Domain scope, or accepts a proposed remediation.
204. `big` is a distinct served-work symptom from `hard`; its label is
     `bi[g]`. `not_important_now`, labeled `[n]ot important now`, replaces
     obsolete priority-based wording and explicitly permits later change.
205. Similar finite choices are grouped on the same visual row without
     ceasing to be distinct one-key actions. Shortcut uniqueness is local to
     the displayed screen, so reuse on another screen is not a conflict.
206. A single `?` is visibly presented as uncertainty about the pending human
     decision, not as unlabeled system help. It opens contextual assistance
     without answering; another `?` inside that screen opens Little Ant system
     help, so `??` is the effective help path.
207. `waiting` and `blocked` are distinct served-work symptoms. `waiting`
     denotes an unresolved external person, event, or condition with no known
     directly actionable work now; `blocked` denotes a representable,
     actionable missing prerequisite such as another Brick, information,
     access, or material.
208. Selecting `blocked` does not itself create a Dependency or enabling
     Brick. Those are possible reactions in a subsequent interaction and
     require their own accepted action.
209. The skip-symptom screen repeats `[d]one` in a visually separate
     “Already finished?” region. It records direct completion only and creates
     no skip symptom, skip cooldown, or avoidance pressure.
210. `Escape` reverses only uncommitted presentation navigation. It restores
     the prior screen without recording or compensating a semantic event.
211. `Backspace` remains text deletion. `C-_` maps to semantic undo and
     `C-M-_` maps to semantic redo; `/undo` and `/redo` expose the same
     operations through the REPL palette.
212. Semantic undo is append-only. It creates a typed compensating event,
     restores the affected interaction using its recorded random evidence,
     and consumes no new focus, comparison, or warning draw.
213. Default undo is limited to the latest reversible semantic action in the
     current interaction. Reversal across sessions, surfaces, or devices
     requires explicit event selection.
214. Redo reapplies compensated intent only while its preconditions remain
     valid. Concurrent conflict is explicit, and an external effect is never
     silently reversed by a Little Ant domain compensation.
215. The primary interaction region contains only its subject, concrete
     question, and valid answers. Composition, Domain, warnings, provenance,
     and compact statistics belong to a visually separate context region.
216. Composition and Domain breadcrumbs render broadest to most specific.
     Empty context rows are omitted; at most one warning is shown with a count
     of additional warnings, and compact statistics occupy at most one line.
217. Product emoji are renderer-owned markers with an accessible no-emoji
     fallback. The compact statistics line uses the Little Ant mascot `🐜`
     rather than a generic chart marker.
218. A guided review is orchestration, not an additional primary screen
     grammar. Its
     presence and honest progress appear discreetly in the secondary context
     region while the current concrete question uses an ordinary interaction
     layout.
219. `*` marks at most one suggested action in a pending interaction, and a
     bare `*` accepts that exact action at the displayed revision. When there
     is no defensible suggestion, no default is displayed.
220. Comparison and confirmation are distinct primary screen grammars.
     Comparison presents two peer subjects and one directional relation;
     confirmation presents one proposed action or effect. The reference
     comparison layout states `#A "..." is more important than #B "..."`
     and asks `Is that right?`.
221. `--dry-run` applies to every state-changing canonical CLI operation. It
     performs ordinary validation and deterministic calculation while writing
     no state, invoking no Pack or external effect, and consuming no persistent
     random draw.
222. A command failure is typed and educational. At minimum, precondition,
     not-found, and ambiguous-reference failures expose stable codes and only
     those recovery actions that the core can validate in the current state.
223. A session with no ordinary eligible opportunity still ends with one
     bounded useful proposal derived from the actual empty-state reason. It
     never fabricates work to satisfy this guarantee.
224. Repeated `other` skip evidence produces a derived taxonomy-review
     opportunity after a configurable threshold. Taxonomy never changes
     automatically; an accepted change is explicit and versioned.
225. The standard 1.0 Pack ships Lua ReadOnlyExporters for tree text, table
     text, CSV, Org, and self-contained HTML. These formats are not hard-coded
     domain renderers.
226. Deterministic product surfaces, canonical content, and Little Ant action
     or effect drafts remain English. Only the operator skill's conversational
     wrapper may be localized, and only by explicit request or operator
     preference.
227. The current v0 operator preference manifest is
     `~/.config/little-ant/ANT.md`. Its settings are deployment/operator
     configuration and never canonical Little Ant domain state.

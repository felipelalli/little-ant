# 17. Corrections and superseded proposals

This section is normative. It prevents earlier, now-incorrect summaries from
being mistaken for current decisions.

| Earlier proposal or wording | Current decision |
|---|---|
| `seed`, `committed`, and `ready` remain as aliases or compatibility states. | Remove them from the 1.0 core. Natural-language compatibility belongs only to the operator. |
| Phase or “derived readiness” sorts the human order. | Phase never sorts priority. It only informs provisional placement and dynamic selection. |
| A Brick's stage combines maturity, execution, and completion. | Use independent `status`, `phase`, `work_state`, and exclusive current focus. |
| Only one human WIP may exist. | Multiple WIPs are allowed; only current focus is exclusive. Default soft WIP limit is 3. |
| Starting a new Brick stops the previous WIP. | It removes focus from the previous Brick but leaves that Brick in WIP. |
| `estimate_hours` remains on Brick. | Remove hours from canonical Brick state. Store a discrete effort class and EffortProfile version; hours exist only in profile, planning, and observed-actual evidence. |
| Effort means a continuously updated remaining-work score from 0 to 1. | Effort is the total work for the current scope, represented by a discrete profile class. Remaining work is a conservative derived projection. |
| Effort needs a global pairwise order like priority. | There is no global effort list or public float. Assisted classification compares a Brick with high-confidence historical exemplars. |
| Progress or focus duration automatically lowers effort. | Progress never changes total effort. Only conservative progress evidence may lower derived remaining effort; focus duration alone is insufficient. |
| TaskJuggler export is necessarily active-leaf-only and parent roll-ups are rejected. | The earlier leaf-only inference is retracted. A confirmed non-overlapping planning cut determines which Little Ant nodes become effort-bearing TaskJuggler leaves for one plan. |
| Parent and child estimates are independent additive effort. | A parent estimate covers its total scope, including descendants. Decomposition coverage and a non-overlapping planning cut prevent double-counting. |
| Export chooses an optimistic, realistic, and pessimistic source estimate separately. | Each planning-cut item chooses one structural macro, and that macro expands to all three scenarios. |
| `PlanningScenario` must be a mutable core entity. | Each confirmed simulation produces an immutable planning manifest outside operational domain state. |
| Scope changes can be inferred semantically by the core and launch one bundled recalibration flow. | The core only raises mechanical `scope_review` suspicion. A human or operator confirms `scope_revised`; affected ordinary probes return through normal cooldown and aging. |
| `weight` remains a generic 0..1 user concept. | Remove ambiguous `weight`; use axis-specific derived scores and selection weights internal to forecast. |
| Impact is a public `impact_score` and `impact_confidence` pair. | Impact uses six expected-impact classes and four evidence-maturity levels. Internal reliability may be derived but is not a public decimal rating. |
| Impact means upside conditional on success. | Impact is expected impact: magnitude already accounts for the chance of occurrence. |
| Impact maturity is the probability of success. | Maturity describes evidence quality and directness; it is independent from the probability already reflected in expected impact. |
| Completing a validation activity automatically upgrades impact. | Purposeful validation is real Brick work. Its result becomes evidence, and a human or operator explicitly reassesses impact and maturity. |
| Difficulty becomes another explicit rating. | Effort is the explicit workload rating; difficulty and friction are derived from behavior and context. |
| Raw is terminal after the first extraction. | Raw is durable and reusable, with orthogonal review and archive state. |
| Raw use consumes it or assigns it to one destination. | Raw-to-Brick and Raw-to-RawShelf uses are many-to-many and non-consuming. |
| Maintenance uses grooming or sanity meta-Bricks. | Use derived proposals such as probes and reviews, not special meta-Bricks. |
| Priority uncertainty is a stored boolean. | Use derived `priority_confidence`; “uncertain” is a projection threshold. |
| Contradictory comparison answers are rejected or immediately reorder by opaque weights. | Preserve the answer, mark the smallest affected segment provisional, and run local recalibration before atomic replacement. |
| Only the latest comparison matters. | Preserve full history, derive a current judgment, and weight newer evidence more strongly within authority rules. |
| The second “next list” is persisted. | Persist only the priority tree; derive forecast as a read-only probability distribution. |
| `digital` mode implies AI execution. | AI work is an explicit Delegation to an `ai_agent`; mode and executor are independent. |
| Product UI or data may remain in pt-BR. | All product commands, responses, shortcuts, data, docs, and canonical values are English. |
| The redesign should be called v2. | The target is Little Ant 1.0. |
| `due_at` plus a generic delay cost models time. | Use distinct `not_before`, `best_before`, and `deadline` semantics. |
| The REPL can wait until 1.5 or be a thin readline wrapper. | A full deterministic guided harness is required in 1.0 and must preserve canonical CLI semantics. |
| `:` opens the REPL command surface. | `/` opens a context-valid command palette in navigation mode; it remains literal during text editing. |

Any earlier consolidation that states one-WIP exclusivity, Brick hours,
continuous public impact or effort scores, remaining effort as the primary
rating, additive parent/child effort, unconditional leaf-only export, mutable
planning scenarios, different macros per scenario, a post-1.0 REPL, or
non-English product data is superseded.

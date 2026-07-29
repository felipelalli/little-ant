# 36. V0 capability regression audit

This chapter inventories useful Little Ant v0 behavior that may have been
lost, weakened, intentionally replaced, or merely left outside the current
1.0 recovery record. It is an audit, not a command-compatibility promise.
Restoring a capability never revives an abolished term or an ambiguous v0
model automatically.

## 36.1 Evidence and method

The audit compares:

- the v0 implementation on `main`, especially `app/Main.hs`,
  `src/LittleAnt/Grammar.hs`, `src/LittleAnt/Order.hs`,
  `src/LittleAnt/Scheduler.hs`, `src/LittleAnt/Tick.hs`, and
  `src/LittleAnt/Command.hs`;
- the v0 tests in `test/Spec.hs`;
- the v0 Allium specification at commit `98dbe1c`;
- the current v0 operator skill in `skills/little-ant/SKILL.md`;
- the current 1.0 conceptual chapters and recovery ledger;
- the propagated Allium garden and `test-v1` artifacts;
- the failed implementation branch `experimental/failed/v1-rewrite`.

The external divergence report was used as a source of leads, but every
finding recorded below was checked independently against repository evidence.

Audit labels mean:

- **restore** — preserve the capability in 1.0, adapted to confirmed 1.0
  semantics;
- **retained** — the conceptual record already preserves or strengthens it;
- **replaced** — 1.0 deliberately chose a different model;
- **review** — the useful behavior is not sufficiently specified to decide
  whether or how it survives;
- **formal drift** — the recovery record has a decision that has not yet been
  propagated into Allium, generated tests, or implementation.

## 36.2 Why validation did not catch the loss

The composed Allium files pass `allium check` and `allium analyse` without
errors or semantic findings. They still contain many informational
`field.unused` diagnostics. This proves structural validity, not behavioral
completeness.

Mechanical inspection of the current formal garden found:

- 141 identifiers or words in the `capture...` family;
- 149 identifiers or words in the `priority...` family;
- 18 references to the obsolete `BrickBehavior` name;
- 11 occurrences of obsolete skip values such as `not_priority`, `meh`,
  `kill`, or `alternatives`;
- no suggested-default or bare-`*` semantics;
- no `org-sort`, adaptive merge-sort, insertion-sort-run, or ordered-halves
  short-circuit mechanics.

The failed v1 CLI contains 15 `optparse-applicative` command declarations,
compared with 64 in v0. These counts are not a quality score: some v0 commands
should disappear, and one contextual command may replace several old ones.
They do prove that a capability-by-capability migration audit did not guard
the rewrite.

The generated directory reports 1,446 Allium obligations and the scenario
suite adds 120 assertions. That volume also failed to protect behavior:

- an Allium `@guarantee` produces no executable obligation;
- `OneKeyFiniteChoices` does not appear in the generated plans;
- the suggested-default marker and adaptive ordering algorithm are absent
  from both generated plans and hand-shaped scenarios;
- generated obligations are dominated by declarations, signatures,
  transition reachability, and rule structure rather than the complete
  product interaction contract.

The degradation therefore crossed several boundaries:

1. Markdown behavior was reduced or mistranslated in the Allium garden;
2. important prose and guarantees produced no test obligation;
3. the hand-written scenarios did not restore the omitted behavior;
4. the failed implementation followed the reduced formal surface.

No later implementation should begin from obligation count alone. Each
confirmed capability needs at least one explicit observable Allium rule,
contract, or invariant and one high-level regression scenario when its
behavior spans several rules.

## 36.3 Interaction and operator grammar

| V0 capability | 1.0 audit result | Required treatment |
|---|---|---|
| `*` marks the suggested default; bare `*` accepts it; no marker is shown without a basis. | **restore** | Section 35.24 restores the marker as part of the canonical interaction grammar. The formal interaction envelope and scenarios still need propagation. |
| Finite choices use one-key input without Enter. | **retained / formal drift** | The conceptual REPL requires it, but the current Allium states it only as a guarantee and generated tests do not exercise the terminal behavior. |
| The core owns letters and markers, and operators inspect rather than invent them. | **restore and strengthen** | `la grammar`, its screen filter, and its JSON projection expose the core-owned global registry; InteractionEnvelope remains the state-scoped source of currently valid actions. |
| A pending question disambiguates a bare answer letter from a full command word. | **replaced in part / review** | The 1.0 `/` palette may replace full-word command escape. Exact raw-command behavior while a one-key prompt is pending still needs a decision. |
| `[l]ater` is a canonical answer and displays the resulting absolute date. | **restore contextually** | It appears only for a time-deferrable proposal, opens explicit date selection, and renders the absolute result. It never appears on focus or comparison. |
| `?` means uncertainty, more information, or help deciding. | **retained and refined** | One `?` now opens decision assistance; nested `?` opens system help. |
| The operator exposes deterministic core output before attributed interpretation. | **retained in principle, review in presentation** | One shared interaction envelope replaces the v0 three-layer shell transcript. Canonical action, provenance, and deeper command detail must remain inspectable without dominating the REPL. |
| Every session ends with a useful proposal rather than silence. | **restore** | When ordinary work is unavailable, return one bounded state-derived inspection, scope, maintenance, feeding, or explicit end/rest proposal without fabricating work. |
| `--dry-run` previews mutations without writing. | **restore and strengthen** | Apply it to every state-changing canonical command with ordinary validation, no persistence, no Pack or effect, and no consumed persistent random draw. |
| Typed errors distinguish precondition, not-found, and ambiguous-reference failures and include a useful hint. | **restore** | Preserve stable machine-readable failure kinds and only core-validated state-scoped recovery actions. Exact codes, exit status, and fields remain open. |
| Product UI and data are English, while outbound messages use the recipient's language. | **replace language exception** | All deterministic product content and Little Ant drafts remain English. Only the operator skill's conversational wrapper may localize by explicit request or preference. |

The working “Proposition” renderer is not accepted as the final user-facing
grammar. The confirmed correction separates **comparison** from
**confirmation** instead of forcing both through one generic layout.
Comparison uses the two-subject assertion and `Is that right?` reference
layout recorded in section 35.25.

## 36.4 Importance-order maintenance

| V0 capability | 1.0 audit result | Required treatment |
|---|---|---|
| Binary insertion asks midpoint questions when placing one new item. | **retained** | Apply only inside the Brick's sibling scope and use the canonical importance question. |
| `org-sort-tasks` bulk maintenance uses insertion sort for short runs, adaptive merge for larger runs, an already-ordered-halves short-circuit, and known transitive answers. | **restore** | Re-specify the algorithm as a resumable core mechanism over one sibling set. It must use importance evidence, never dependency edges. |
| A bulk sort asks at most one new pair per invocation and resumes from persisted judgments. | **restore** | The REPL may conduct several steps, but every accepted answer remains an ordinary judgment event and interruption loses no progress. |
| `order --questions` surfaces informative unresolved adjacent pairs. | **restore in corrected form** | Integrate manual question rounds, forecast probes, confidence, and provocative validation without creating a second ordering mechanism. |
| Burst and time drift trigger an order sanity round. | **restore in corrected form** | Produce a derived review opportunity, not a meta-Brick. Thresholds and cadence are configurable calibration parameters. |
| Comparisons become stale and are revalidated. | **retained and strengthened** | The 1.0 history, authority, decay, contradiction, confidence, and local recalibration model supersedes the single stale flag. |
| Dependencies contribute hard edges to the same total order and prohibit the opposite comparison. | **replaced** | Dependencies never rewrite importance. A blocked Brick keeps its sibling position and may still be compared by importance. |
| Comparison cycles are broken silently by creation order. | **replaced** | Contradictions reduce confidence and trigger explicit local recalibration; they are not hidden by a deterministic cycle break. |

Adapting `org-sort-tasks` requires care because 1.0 gives every Brick a
provisional position from birth. The current position is not automatically
human evidence. Bulk maintenance must distinguish:

- the canonical strict order used for display;
- known directional evidence that can answer a comparison;
- provisional tie-breaking that must not masquerade as an answer;
- the low-confidence segment currently being recalibrated.

The exact adaptation remains a specification task, but losing the adaptive,
tolerant, resumable algorithm is not acceptable.

## 36.5 Focus forecast and scoping

| V0 capability | 1.0 audit result | Required treatment |
|---|---|---|
| Foreground/background queues, a periodic background turn, and oldest-first anti-starvation. | **replaced** | Use the confirmed hierarchical replay-deterministic weighted lottery, positive long tail, aging, and recorded random evidence. |
| A focus flow accepts `ignore`, `prefer`, or `require` context strictness. | **review** | Soft preference is replaced by active-Domain continuity. The equivalent of explicitly ignoring continuity, switching Domain, and imposing a hard temporary Domain scope still needs a coherent grammar. |
| `next` refuses to run without an open flow. | **replaced** | The 1.0 REPL is itself the persistent harness. Exact CLI continuity and non-REPL invocation semantics remain open. |
| Waiting or blocked work is removed from the executable frontier. | **replaced and strengthened** | It may remain in the initial attention draw, then resolve through an N-step dependency path to an actionable endpoint. External waits with no endpoint still need a result design. |
| Anti-starvation is a deterministic bounded cadence. | **replaced, open guarantee** | Positive probability and aging are confirmed, but whether 1.0 needs a bounded service guarantee remains open. |

## 36.6 Skip, avoidance, and adaptation

| V0 capability | 1.0 audit result | Required treatment |
|---|---|---|
| Every served skip records its reason and preserves optional verbatim text. | **retained** | Preserve the distinction among served, ordering, rating, and practice skips. |
| Each skip reason immediately maps to a typed reaction. | **review** | The 1.0 symptom-first model is better, but the reaction catalog and symptom-to-reaction rules are incomplete and must not be improvised during implementation. |
| `other` requires raw text and repeated `other` reports trigger taxonomy review. | **restore and strengthen** | Repeated attributed evidence creates a derived weighted taxonomy-review opportunity. No taxonomy mutation occurs without explicit versioned acceptance. |
| `vague` regresses the old lifecycle stage and may create a clarification meta-Brick. | **replaced** | Keep the symptom, then offer a phase review, description/specification work, or an explicit enabling Brick when appropriate; never regress a removed stage or auto-create a meta-Brick. |
| `not_priority`, `meh`, `kill`, and `alternatives` are skip reasons. | **replaced** | Use `not_important_now` and `fear`; terminal drop and alternative-method selection are later actions, not symptoms. |
| `hard`, `waiting`, and other symptoms have domain-sensitive consequences. | **retained in direction, incomplete** | Nature, Domain, dependencies, waits, effort, and decomposition must constrain the later reaction choices. |

## 36.7 Work, delegation, and effects

| V0 capability | 1.0 audit result | Required treatment |
|---|---|---|
| One WIP can become dangling and is flagged once after a threshold. | **replaced and strengthened** | Multiple WIPs plus one current focus use `review_wip` and `stale_focus`; exact timers and idempotent notice mechanics remain open. |
| Start, stop, and done are explicit and auditable. | **retained, command grammar open** | Preserve honest execution history while distinguishing finite completion from a standing-work occurrence. |
| Delegation has draft/notice approval, cancellation before notice, due follow-ups, approve/decline nudge, and terminal completed/refused/abandoned outcomes. | **partly restore / review lifecycle** | Every Delegation now requires one-time, repeating, or explicit-none follow-up policy; repeating schedules approval-bearing opportunities only. Compact statuses, outcome names, scope, and effect flow remain under review. |
| `abandoned` is a delegation outcome. | **historical fact, review name** | It existed in v0; it was not invented by the failed rewrite. The generic public `interaction abandon` is different, is not justified by v0, and must not be accepted by association. |
| Completion can arm `write_back`, `notify`, or `spawn`; external effects stop for preview and approval. | **split replacement** | Explicit external approval is retained. Arbitrary completion-time `spawn` is replaced by restricted event-triggered opportunity release. Generic notification and write-back use cases still need a complete 1.0 effect model. |
| Delegated work is independent from human focus. | **retained and strengthened** | It consumes neither current focus nor the human WIP count and returns through ordinary forecast opportunities. |

## 36.8 Identity, composition, and lifecycle

| V0 capability | 1.0 audit result | Required treatment |
|---|---|---|
| Title collision blocks creation. | **replaced** | Opaque identity permits duplicate titles; duplicate suspicion proposes reuse, enrichment, merge, or separate creation without silent mutation. |
| `unify` retargets relationships and removes would-be self-comparisons. | **replace with explicit merge** | `merge` is previewable, atomic, source-to-survivor, and conflict-blocking. It preserves immutable history and terminal source lineage; `unify` is not retained as an alias. |
| `supersede` preserves lineage, source links, and the old order slot. | **partly replaced / review** | Lineage survives. Standing work explicitly forbids silent transfer of placement and recurrence. General finite-Brick successor placement and selected relationship transfer remain open. |
| Breaking work creates children and removes a non-leaf parent from direct execution. | **retained and strengthened** | Nature decides whether descendant focus applies; hierarchy and parent closure are explicit. |
| Closing a parent re-roots open children automatically. | **replaced / review exact batch action** | 1.0 rejects simple closure with active descendants and requires an explicit subtree operation. It must not silently re-root children. |
| `seed`, `committed`, and `ready` stages organize preparation. | **replaced** | Importance, optional phase, Nature, structure, evidence, work state, and focus are independent axes. |
| `weight` and hour estimates live on each Brick. | **replaced** | Use total-effort classes, expected-impact evidence, planning cuts, and TaskJuggler calibration outside canonical hour fields. |
| `atomicity`, `mode`, `about`, requester, description, waits, dependencies, delegation, source, and effects are independent metadata or relationships. | **partly retained / review** | None was implicitly removed by the conceptual redesign, but several exact commands and behaviors are still unresolved. |

## 36.9 Raw, sources, planning, and projections

| V0 capability | 1.0 audit result | Required treatment |
|---|---|---|
| Raw input is preserved and may extract zero or more work items. | **retained and strengthened** | Raw is durable, reusable, versioned material with review and archive axes. |
| Feeding is lazy and does not require a metadata form before work can enter the system. | **retained and strengthened** | Nature is required from birth but may safely fall back to `standard`; phase, effort, Domain, and other enrichment remain lazy. |
| A source check detects drift and requires explicit reconciliation. | **retained and strengthened** | RawOrigin, snapshots, RawLinks, per-link baselines, source observations, and approved write-back replace one mutable SourceLink fingerprint. |
| External actions never happen silently. | **retained** | This remains an absolute authority boundary for core, adapters, Packs, REPL, and skill. |
| TaskJuggler export includes dependencies, ordering, estimates, and visible gaps. | **replaced and strengthened** | Planning cuts, EffortProfiles, immutable manifests, Lua read-only export, and separate actual import are the 1.0 model. |
| Tree, one-line, table, CSV, Org, and self-contained HTML projections exist. | **restore through Pack boundary** | Tree, table, CSV, Org, and self-contained HTML ship as standard Lua ReadOnlyExporters over core-owned structural projections. Compact one-line rendering remains part of ordinary core inspection. |
| `show`, `ls`, `status`, raw event access, and compact human output support inspection. | **retained in architecture, incomplete grammar** | Sparse typed responses, complete projections, status, filtered history, and audit access are stronger, but exact CLI queries and human renderings remain open. |
| Every command lazily fires due temporal rules; `tick` can run them explicitly. | **restore and strengthen** | Every command begins one idempotent deterministic time-advancement phase; `la tick` and `la tick --dry-run` expose the same phase explicitly. |
| Migration supports versioned upcasting, atomic rewrite, dry-run, and backup. | **retained in direction, incomplete contract** | The 1.0 migration model is richer, but the exact event upcast, verification, backup, rollback, and command contract remain open. |

## 36.10 Required gates before another implementation

Before regenerating Allium tests or starting another 1.0 implementation:

1. settle the remaining focus, choice, input, `*` authority, `?` assistance,
   and status/context details around the confirmed comparison and confirmation
   grammars;
2. specify adaptive sibling-order maintenance as observable core behavior;
3. review every **review** row above and either restore, replace, defer
   explicitly, or reject it;
4. propagate confirmed vocabulary and models into Allium before generating
   tests;
5. express cross-rule behavior in end-to-end scenarios rather than relying on
   comments, guarantees, or obligation totals;
6. add an explicit v0-capability regression suite so every intentional removal
   and replacement is named and every surviving capability has coverage;
7. audit the generated plan to prove that each required behavior actually
   produced an obligation or is covered by a hand-written scenario.

This gate does not require preserving 64 commands. It requires preserving
intentional product capability without ambiguous aliases or accidental loss.

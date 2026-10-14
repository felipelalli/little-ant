# Spec and REPL review — 2026-10-10

The v1 branch implements a substantial local alpha, but does not yet satisfy
the complete 1.0 specification. This review checks the canonical command and
interaction contracts against the dispatcher, projections, terminal loop,
provider host, release boundary, and executable evidence. Subsequent user
feedback includes an explicit exit-contract revision and a rebuilt signed
built-in standard Pack, version 1.0.1, for the HTML explorer.

## Corrected defects

| Finding | Correction and evidence |
|---|---|
| `/list` was advertised but had no REPL route. | Added direct importance browsing, pinned v/t controls for forecast/category trees, local Ctrl-F search, optional Brick/Domain scope, keyboard selection, and inspection. See UX-280 and `command-catalog.md`. |
| `show #brick` attempted to parse a Raw, and search ignored typed prefixes. | Generalized read-only inspection to Bricks, Raw, Domains, entities, entries, shelves, and forecast effects. Search resolves `#`, `+`, and `@` handles and retains completed/archived objects. |
| Opening a Raw's guided inspection replaced the pending interaction. | Browsing uses the complete read-only projection. Ctrl-F suspends the exact editor, selection, and scroll position; Escape restores it. Application tests prove the cursor, pending interaction, and random draw state do not change. |
| Forecast browsing listed tickets without their actual selection chances. | Added exact rational marginal endpoint probabilities from the same hierarchical weights and dependency forwarding used by `next`, without drawing. Displays chance, age where available, strongest signal, Domain alternatives, and opportunity kinds. Fixed-time commitments and retained focus get their precedence rather than a simulated draw. |
| The real migrated dataset passed `doctor` but `next` could crash on a dependency to completed or unavailable work. | Treat historical completed prerequisites as satisfied, admit dependency branches only when their endpoint is eligible, and use the same filter for forecast inspection. New migrations append dependency resolution with completion. Regression tests cover completed legacy blockers, unavailable endpoints, and mixed blocker branches. |
| Long output and smaller terminals clipped useful content. | Read initial terminal bounds, wrap by terminal cell width, preserve footer, scroll details/help, and keep selected browser rows visible. Long URL and wide-character cases are tested. |
| Paste events were discarded, editor cursor display added a spurious space, and shortcuts removed letters from option labels. | Support bracketed paste in text and credential inputs, highlight the actual cursor character, and insert shortcut brackets at their true position in the label. |
| The palette accepted only query text, dropped arguments, and advertised operations without handlers. | Preserve typed command arguments and route the implemented lifecycle, judgment, configuration, and browsing commands to the canonical dispatcher. Current focus now exposes `/done` as well as its primary action. Undo returns its updated interaction. |
| Read-only text closed on any key and forgot its originating screen. | Detail/help views require explicit back navigation and preserve their parent screen. |
| Provider accounts omitted defaults from their authenticated configuration schemas. | Apply missing signed schema defaults when connecting and when executing existing accounts; preserve explicit configuration values. The Microsoft connector receives its expected task-filter options. |
| Microsoft Graph gzip responses reached Lua as compressed bytes. | Enable HTTP decompression and enforce the existing body limit on decompressed bytes. A real HTTP fixture verifies gzip JSON and rejects a compressed response expanding beyond 16 MiB. |
| Official Pack discovery used the `main` branch, whose v0 tree lacks the catalog. | Fetch the signed catalog published on `v1`; existing signature/trust checks still apply. |
| Oversized AF_UNIX vault paths crashed with a socket-library exception. | Validate encoded path length and return a typed error for client and server, before binding. |
| CI invoked Pack verification before creating the Cabal package database and also failed on old HLint hints. | Make Pack verification depend on build; resolve mechanical lint findings. One narrowly scoped lint exception preserves the existing `CutoverJournal` data representation and its evaluation behavior. |
| HTML exported a styled composition list that looked flat for the real dataset and gave no category/dependency navigation. | Add native collapsible category trees with ancestor context, composition, unresolved prerequisites, and links across views. Keep exports self-contained and script-free, and retain scope boundaries without exporting unrelated titles. |
| The REPL's `[n]ext` shortcut called the checkpoint-restoring startup command and could remain on a creation receipt indefinitely. | Dispatch the envelope's validated `next` response to request the next recorded opportunity. Startup after `/exit` continues to restore the pending proposal. A real-PTY regression covers both advancing past creation and retaining that proposal across restart. |
| A creation receipt could claim its new Brick was above itself. | Exclude that Brick from its own neighbor description; a singleton correctly shows `only sibling`. The same PTY flow verifies the truthful receipt. |
| Focus `[?] I don't know` only appended generic decision instructions; the initial assistance route then asked whether reading would suffice before showing context. | Following the user's approved October 12 refinement, open the complete existing `/show` projection immediately, ask about clarity after reading, and require separate final Focus consent. Recorded selection evidence is optional; explicit missing understanding reuses vague recovery. Back/restart, legacy-checkpoint upgrade, random-state preservation, and unrelated current-focus preservation have application regressions. |
| Vty discarded empty rows, making titles, explanations, and Markdown appear glued together while scrolling counted invisible rows. | Give every model row a terminal row. Distinguish headings, questions, and body; format Markdown headings, emphasis, inline/fenced code, and links. Reflow and justify ordinary paragraphs inside 96 display cells while preserving lists, metadata, and code alignment. |
| Paginated screens ignored the mouse wheel; scrolling up after End could leave the viewport stuck at the bottom. | Capture vertical wheel events only for overflowing documents, opportunities, and selectors. Scroll documents by three rows and selectors by one item without activation. Clamp offsets against the real viewport range. A real-PTY regression covers both directions, End followed by wheel-up, selectors, and unchanged checkpoint/events at 80 and 28 columns. |
| The migrated snapshot/hot-log/cold-archive Work remained unimplemented in v1. | Add a disposable checksummed binary fold cache and rotate covered immutable command segments into UTC-quarter directories every 128 accepted groups. Keep original bytes and filenames. Snapshot publication precedes durable copy and hot unlink; readers retry a concurrently replaced cache. Full diagnostics, semantic history, and repair include cold files. Tests cover missing/corrupt cache, interrupted moves, divergent duplicates, automatic rotation, focus/random-state retention, and later Work restore. See ADR 0038. |
| Current-focus `done` required another `next`, while `/done` skipped its completion receipt and exposed an unrecorded candidate. | Both paths now return the same durable completion result. The REPL advances its ordinary `next` continuation once and keeps a completion fact above the next opportunity until user input. Resize retains the fact. Separate Focus consent, safe-empty output, repeatable return-policy questions, and a standalone noninteractive completion result remain explicit. A continuation error leaves the committed result available for next-only retry. |

| Retired prerequisites could retain active dependencies and make their dependents unreachable. | Lifecycle folds now mark incoming and outgoing edges removed, retain identities and provenance, and replay older explicit resolutions. Archive/restore previews disclose the relationship effect. Forecast and inspection share the effective-edge predicate, and format-1 snapshots rebuild after the semantic version bump. Tests cover archived/superseded/merged retirement, unrelated edges, restored Work, old resolution ordering, terminal legacy endpoints, and narrow disclosures. |

## Validation

`make ci` passed locally on this working tree: canonical-ID audit, vocabulary guard, coverage
report, signed Pack reconstruction/catalog verification, formatting, HLint,
Cabal package checks, build, all 30 Haskell suites, conformance tests, CLI
integration, and a new real-PTY REPL suite.

The PTY suite exercises an unsubmitted pasted Feed draft through search and
back navigation, the full Raw-to-Brick-to-focus-to-done loop, inspecting long
attached material, and a 28-column terminal. Application and forecast tests
cover event-free inspection, scoped browsing, archived/completed search,
hierarchical probabilities, combined blocker probability, and hard scope.
Provider tests cover signed defaults and the actual gzip transport path.
The production catalog refresh also succeeded in an isolated profile,
verifying signed sequence 2 with expiry 2028-08-09. The copied real dataset
passed `doctor` and `next`; importance browsing returns 53 Bricks. A real PTY
also exercised the copied dataset's last list row, detail inspection, return
navigation, and typed search. Original dataset hashes stayed unchanged. The
complete CI gate passed with the legacy dependency regression fixes included.

The HTML explorer was exercised in Chromium at desktop and mobile sizes and
in light and dark themes. Category branches collapse by mouse and keyboard;
Brick links reveal a collapsed composition ancestor and select the target.
All 53 exported Bricks remain reachable, with 9 categories and 7 unresolved
dependency edges. No horizontal overflow or page errors were observed. The
real copied dataset also resumed the exact same interaction after `/exit`
and `next`, with identical checkpoint bytes and event hashes. The PTY suite
now covers that retained Focus-proposal case as well as retained current focus.

The subsequent reading feedback adds an eighth PTY case for Focus uncertainty,
actual context inspection, Markdown rendering, spacing, and returning before
consent. Application tests verify immediate context, post-reading clarity,
optional recorded evidence, and upgrading legacy question-first checkpoints.
They preserve event state, random cursors, and unrelated current focus.
The simplified Focus route was also exercised against the copied dataset at
28 and 128 columns, including optional draw inspection, return to context,
and separate clarity and consent screens; the event files stayed unchanged.
Renderer regressions verify real blank-row height, Unicode cell bounds,
paragraph justification, left-aligned structured material, wrapped-title
hierarchy, and complete narrow scroll hints. The task from the user's capture
was also projected at 28, 80, and 128 columns and inspected in wide and narrow
previews; all 464 original dataset files retain their baseline hashes.

The October 12 storage work was measured in a disposable copy of the current
review dataset: 771 accepted events in 461 command segments. The cached and
complete folds were identical, including current Focus, and history returned
every accepted record after rotation. Across five fully evaluated loads per
mode, complete replay averaged 60.4 ms and cached loading 32.7 ms. The normal
cached load decoded no cold event records. Both the live review copy and the
original dataset were unchanged. The ninth PTY case confirms mouse scrolling
in documents and selectors without changing checkpoint bytes or events.

The completion refinement adds a tenth PTY case covering `d`, `/done`, and
startup with a pending noninteractive completion, at 80 and 28 columns. Each
produces exactly one following recorded draw, leaves the successor idle, and
restores the same checkpoint/event bytes across exit and restart. Resize
retains the completion fact; opening search consumes it without redrawing.
The existing final-Work case verifies safe-empty output with its receipt.
An application regression verifies that noninteractive `done` itself records
no forecast draw and returns the same durable completion after restart.

The October 12 shortcut refinement reserves `k` for finite uncertainty, moves
keep choices to `e` and import synchronization to `y`, names Focus navigation
destinations, and removes the duplicate task citation in context. Existing
validated checkpoints are upgraded, including both navigation stacks, without
changing action IDs, canonical data, or the selected draw. Historical frame
and restore evidence used the retired shortcut and has been archived in
`2026-10-12-superseded-shortcut-evidence.json`; those two formal flows are
implemented pending renewed surface evidence rather than silently rebinding
their verified hashes. Application, renderer, Pack, and real-PTY regressions
validate the new behavior.

The October 13 dependency correction passed the complete CI gate, including
all 30 Haskell suites and 10 real-PTY tests. A subsequent targeted consent
regression also checks that a saved archive preview is refreshed before its
old token can authorize the changed relationship effect. The final CI gate
passed with that checkpoint upgrade included. Read-only inspection of the
real review copy confirmed that its active-to-archived prerequisite is now
removed and remains visible in complete inspection. Those read-only checks
preserved all 463 canonical segments. The user-approved completion of
`#bbdcccbed` then appended exactly one `brick_completed` event in the review
profile and triggered automatic snapshot publication/cold rotation. All 464
canonical filename hashes verified after the move, all 459 copied original
segments matched their baseline bytes, and all 464 baseline files in the
official dataset remained unchanged.

The October 13 Forte+ calibration replaces the factory quadratic importance
curve with a 60% full-confidence local head and a softer geometric tail:
ratio 0.70, with 2% uniform exploration inside the remaining share. The neutral
confidence interpolation remains 0.35. The revised profile identifier applies
to new draws; historical weights, choices, and purpose cursors replay intact.
The calculation spec, parameter registry, reference vectors, README chart,
and standalone simulator reflect the accepted curve.

The final `make ci` passed with all 30 Haskell suites, 16 conformance tests,
CLI integration, and 10 real-PTY cases. New regressions cover group sizes,
confidence dilution, local and hierarchical inspection, exact reference
weights, and historical profile replay. Read-only inspection of the review
copy returned 52 forecast endpoints, with a highest current chance of 5.3%;
unequal confidence and context explain why this differs from the fully
confident illustrative 60%. `doctor` replayed 775 events across 464 canonical
segments successfully. Canonical segments and presentation checkpoints in
both the review copy and official dataset retained their pre-inspection hashes.

The composition-list refinement adds `├──`, `│`, and `└──` connectors to the
REPL and plain CLI. A tree search retains matching branches and ancestor
context, and selection uses that same visible sequence. Scoped roots are
rebased, preventing a Domain-filtered child from appearing under an unrelated
parent. Narrow terminals wrap ordinary words while continuing branch guides.
Surface and application regressions cover branching, filtering, selection,
subtree scopes, and pagination. Real PTY checks at 80 and 28 columns inspected
the selected grandchild in a disposable copy and preserved the live review
dataset and all 464 original-baseline file hashes.

The review dataset now also contains six explicitly hypothetical `[DEMO]`
Bricks under `#dpa`, including two grandchildren. They were created through
the ordinary validated Feed, Work-materialization, and decomposition decisions
in four command groups totaling 15 events. Full replay passed; existing Focus
and forecast evidence were preserved. They have no direct Domain assignment.
The user-approved direct `/list` default, pinned `v`/`t` controls, and combined
category/composition tree are now implemented. Ctrl-F searches locally and owns
text input, preserving literal shortcut letters. Category references retain the
same forecast rows and context-only ancestors have no invented chance. The
HTML exporter now nests parts inside category/project branches too, retaining
native disclosure and separate composition/dependency sections.

The local search field uses Ctrl-F again to finish typing while retaining its
query, so view and grouping switches can operate on filtered results. Escape
clears the search before leaving the list. Grouping includes archived Work's
relevance-review opportunities, even though these are absent from active
importance order; a regression covers their exact forecast row and read-only
behavior. Pinned controls stay reachable in narrow paginated lists, and the
viewport keeps every wrapped line of a selected title visible when it fits.
HTML checks at 1120 and 390 pixels found every active Brick reachable without
horizontal overflow and verified keyboard disclosure and hidden fragment targets.

## Remaining gaps

- The formal coverage register still labels only 6 of 65 flows verified,
  16 implemented, and 43 planned. These are evidence labels; many planned
  rows already have partial implementation. Passing the current gate does
  not prove all 894 canonical rules or all surface parity obligations.
- Source binding `check` currently explains the required observation protocol
  rather than performing a complete source check. Imports are usable for
  experiments; ongoing observation/reconciliation is not a finished sync
  service. Local Brick edits do not produce two-way Microsoft To Do updates.
- Merge and supersede, complete migration/repair vocabulary, Calendar
  reconciliation/write-back, recurring and habit edge cases, and advanced
  Wait/Delegation/effect paths need the beta work listed in
  [v1-beta.md](../releases/v1-beta.md).
- Powered-up mode, the final Skill mirror, and `local_web` have no verified
  parity with the dumb REPL. Forecast detail is a useful bounded summary;
  the final per-variant explanation/history expansion still needs work.
- The subsequent feedback adds undisplayed `q`, root-main Escape, and the exact
  REPL-only `/quit` spelling for `/exit`; the canonical contract records this
  explicit exception. Editor/filter input and nested Escape remain intact.
  Forecast rows now expose sibling position, parent, and importance confidence.
  The initial copied-data check found 53 forecast rows at 1.2–3.8%, with 43
  Brick tickets at provisional 15% importance confidence. The HTML exporter
  includes an offline category/composition/dependency explorer. At that check,
  all 53 Bricks were roots, explaining the absence of nested parts. The
  hypothetical sample above now exercises deeper composition. A live web
  adapter is still beta work.

The private test launcher uses a copied dataset in `~/tmp`, fresh profile
configuration, and no copied vault or integration credentials. During the
isolated review, the installed alpha, original dataset, and upstream providers
remained untouched. The later user-authorized promotion to
`main` and alpha.2 release are recorded separately in the
[release notes](../releases/v1-alpha.2.md). The two reviewed completion intents
were subsequently applied selectively to the official profile with a verified
backup and full replay; no demo creation or test draws were imported.

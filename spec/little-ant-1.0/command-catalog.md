# Canonical command catalog

Status: **normative 1.0 public command registry**

Little Ant has one public vocabulary. The dumb REPL is the discoverable
reference: `/` shows only commands valid for the current interaction, missing
arguments open the ordinary guided selector, and no one must memorize a
handle. The CLI exposes the same semantic operations for scripts and other
surfaces. Powered-up mode and the operator Skill may interpret natural
language, but they render and invoke one command from this registry rather
than inventing another verb.

Any public command absent from this catalog does not exist in 1.0. In
particular, there are no compatibility aliases except the explicitly declared
REPL-only `/quit` spelling for `/exit`. A rejected spelling receives
an educational error with the nearest canonical command and performs no
mutation.

## Grammar

- `lant` starts the dumb REPL and immediately obtains or restores an
  opportunity. `lant --power-up <executable>` starts the same REPL with the
  validated stdin/stdout assistant described by UX-034..039.
- A slash identifier is one lowercase kebab-case token. Whitespace begins its
  arguments. The CLI uses the same top-level token except for the explicitly
  listed administrative namespaces.
- Square brackets below mean an optional argument, angle brackets mean a
  required value, and `reference` means a typed `#`, `+`, `@`, or Domain
  reference allowed by that operation. They are notation, not literal input.
- In the REPL, an omitted argument is guided under UX-195. In noninteractive
  CLI use, an omitted required argument is a typed `precondition` error with
  the exact usage; it never guesses from recency.
- Every catalogued CLI operation accepts global `--dry-run`. A mutating form
  traverses the same parsing, resolution, validation, tick, preview, and
  permission path without appending events, advancing persistent randomness,
  or dispatching external effects. An inherently read-only form returns its
  ordinary validated projection with the dry-run
  fact visible; the option grants no additional authority and is never an
  unnecessary-option error.
- The global profile selector precedes the command as `--profile <name>`.
  Common structured-output and presentation options appear where each
  command's help declares them. Sparse JSON is the default structured
  projection; explicit audit projections may include absent values when their
  schema requires them.
- `--view guided show +RAW` opens that exact Raw's guided workflow. It is an
  interaction-opening form, unlike the ordinary read-only detail depths.
- Global `--non-interactive` forbids REPL startup and terminal prompts. Every
  implemented guided operation remains reachable through the headless
  interaction transport below; the flag never chooses an answer. Explicit
  piped material remains valid. `--secret-stdin` supplies secrets as separate
  stdin lines, without echo or secret-bearing arguments; creation and rotation
  require the new passphrase twice. Provider browser authorization may still
  require the account owner's external approval.

## Headless interaction transport

`lant interaction` is a CLI-only transport namespace, not another Work verb or
a slash alias. It exposes the same envelopes and dispatcher used by the REPL:

| CLI form | Meaning |
|---|---|
| `lant interaction show` | Inspect the saved pending envelope without ticking, drawing, refreshing, or changing its checkpoint; fail if none exists. |
| `lant interaction respond --from FILE --action ACTION_ID [--text TEXT\|--text-file FILE]` | Answer one exact action from the supplied envelope, optionally submitting input text. |
| `lant interaction back --from FILE` | Move to the preceding presentation checkpoint, bound to the supplied current envelope. |
| `lant interaction forward --from FILE` | Move to the retained forward presentation checkpoint with the same binding. |

`--from` accepts a JSON envelope or the complete JSON command result containing
it. `-` reads stdin; `--text-file -` likewise reads UTF-8 text from stdin. Both
inputs cannot consume stdin in one invocation. Text is valid only for an input
interaction. Actions use exact IDs from that envelope, not simulated keypresses.
Identity, revision, cursor, token, and semantic preconditions are validated
before answering. A replaced or relevantly stale interaction fails with
`stale_interaction` and never transfers its answer to another question.
Back/forward only navigate; they do not supply consent or undo domain events.

Structured command results include `status`: `completed`, `awaiting_input`, or
`simulated`. A completed Feed or response may also carry the next interaction;
that does not undo completion of its accepted operation. With
`--non-interactive`, exit 0 means completion, successful inspection, or dry-run;
exit 2 accompanies a result awaiting an answer; exit 1 means an error.
`interaction show` exits 0 for successful inspection even when its envelope
awaits an answer. Without the flag, successfully opening a guided interaction
retains exit 0 for compatibility. Raw exporter output remains raw bytes.

`lant archive BRICK --yes` and `lant restore BRICK --yes` explicitly accept
only that invocation's lifecycle preview through the same dispatcher. Archive
still removes the previewed dependencies and creates its relevance review;
neither route requires accepting Focus. Without `--yes`, the preview remains
pending. `lant update BRICK title|description --text TEXT|--text-file FILE`
submits an exact value to the ordinary revision preview; adding `--yes`
accepts that revision. `--yes` without a field and value is invalid for update.
These forms do not answer other judgments, accept a replacement question, or
provide a general affirmative-answer loop. Global `--dry-run` validates the
entire requested operation without persisting even an intermediate checkpoint.

UI controls such as opening Feed or the command palette are presentation
controls: headless callers use `feed` or the envelope's canonical commands.
An implementation marked `unsupported` remains unavailable; non-interactive
transport does not claim implementation of deferred product features.

## Daily work and organization

| REPL command | CLI form | Meaning |
|---|---|---|
| `/why` | `lant why` | Inspect the current recorded selection without drawing, answering, or changing the checkpoint; `--view complete` exposes replay details. |
| `/next` | `lant next` | Obtain one replay-recorded opportunity without silently replacing current focus. |
| `/feed [text]` | `lant feed [text]` | Preserve one new item as Inbox Raw before any lazy classification. |
| `/focus [#brick]` | `lant focus <#brick>` | Ask the ordinary `Focus?` question for named Work, or resume its WIP continuation. |
| `/focus-blocker` | `lant focus-blocker <#brick>` | From a visible blocker chain, ask `Focus?` for its named executable blocker without claiming it started. |
| `/pause` | `lant pause` | End the current focus interval while retaining the Brick as WIP. |
| `/return-to-idle [#brick]` | `lant return-to-idle <#brick>` | Clear focus/WIP without claiming an outcome. |
| `/done [#brick]` | `lant done <#brick>` | Record the Nature-owned truthful completion outcome. |
| `/finish [#brick]` | `lant finish <#brick>` | Finish only an active checklist run; it is unavailable elsewhere. |
| `/archive [#brick]` | `lant archive <#brick>` | Stop pursuing Work after previewing removal of its affected dependencies, without claiming completion. |
| `/restore [#brick]` | `lant restore <#brick>` | Restore archived Work through its lifecycle preview. |
| `/break [#brick]` | `lant break <#brick>` | Enter the accepted decomposition flow without fabricating a `big` symptom. |
| `/order [scope]` | `lant order [scope]` | Run continuous human importance ordering for all groups, one sibling group, or one Domain. |
| `/tie-break` | `lant tie-break` | Resolve only the pending skipped importance comparison through its deterministic aid. |
| `/domain-focus [Domain]` | `lant domain focus <Domain>` | Choose one suggestion, stay within, or prefer a Domain. |
| `/update [reference] [section]` | `lant update <reference> [section]` | Open the one semantic-maintenance hub; there is no generic field editor. |
| `/merge [#survivor] [#absorbed]` | `lant merge <#survivor> <#absorbed>` | Merge two Bricks through the complete transfer/conflict preview. |
| `/supersede [#old] [#replacement]` | `lant supersede <#old> <#replacement>` | Record that one Brick has been replaced by another. |

`lant domain` is the separate Domain-forest manager defined by FED-058. Its
closed subcommands are `show`, `create`, `rename`, `move`, `merge`, `archive`,
`restore`, `members`, and `focus`. This administrative namespace does not
create slash aliases for each subcommand; `/domain-focus` remains the common
human shortcut for its focus behavior.

## Judgment, inspection, and recovery

| REPL command | CLI form | Meaning |
|---|---|---|
| `/impact [#brick]` | `lant impact set|clear|show <#brick>` | Review or inspect expected-effect evidence without creating a priority score. |
| `/effort [#brick]` | `lant effort set|clear|show <#brick>` | Review or inspect subjective effort without storing hours as truth. |
| `/list [importance\|forecast] [scope]` | `lant list importance\|forecast [scope]` | View the human importance tree or the read-only current Focus forecast. |
| `/show [reference]` | `lant show <reference>` | Inspect one canonical object through its sparse summary/detail projection. |
| `/search [query]` | `lant search <query>` | Search globally across typed references; `Ctrl-F` opens this route outside `/list`, where it searches the current list. |
| `/history [filters]` | `lant history [filters]` | Search bounded semantic history rather than dump the event log. |
| `/notices` | `lant notices` | Inspect current, acknowledged, and snoozed temporal notices. |
| `/translate [scope]` | `lant translate [scope]` | Run the interruptible English-normalization review queue. |
| `/undo [command-id]` | `lant undo [command-id]` | Append the declared compensation for one reversible action. |
| `/redo` | `lant redo` | Reapply the currently redoable intent when its preconditions still hold. |

`/list` opens importance order directly in the REPL. The CLI still requires
an explicit `importance` or `forecast` name. The REPL pins these controls above
the ordinary product footer, even while paging:

```text
[v] forecast · [t] categories on · Ctrl+F search
↑/↓ select · Enter inspect · Esc back · [/] more
```

`v` alternates importance and forecast, retaining the query, scope, grouping,
and selected Brick where it exists in the other view. `t` toggles a combined
category and composition tree; forecast rows keep the same chances. Direct
category membership is never inherited from a project. Unclassified parts can
appear inside their classified project's branch as composition context, with
that absence of direct classification disclosed. A multiply classified Brick
can appear in several branches as references to the same object, never as
additional probability mass. Context-only forecast ancestors have no invented
chance. Dependencies retain a separate view rather than masquerading as parts.

Ctrl+F searches the current list. While the search owns input, `v`, `t`, and
slash are literal text. Ctrl+F again finishes typing and keeps the query so
view/grouping controls can operate on the filtered results. Matching parts retain ancestors; matching branches
retain their parts. Enter inspects the selected item; Escape clears the search
and restores the complete list before a subsequent Escape returns to the
suspended interaction. `/search` remains available for global discovery.

`importance` never renders a fake global score: it renders the composition
tree and strict order within each sibling group, using `├──`, `│`, and `└──`
connectors. Searching that tree retains the ancestors of matching parts, and
a matching project retains its parts. Scoped trees start at their visible
roots; a hidden parent never attaches a child to an unrelated visible Brick.
`forecast` renders each
admitted attention subject's current positive chance, opportunity variant,
age, strongest signal, effective Domain path, and blocker endpoint. Brick rows
also show their sibling-local importance position, parent, and the confidence
used for importance weighting. A percentage is the marginal chance of reaching
that attention subject in a new flexible draw by `next`, after dependency
forwarding; it is not completion progress or a global importance score. Neither
view consumes randomness or changes importance. Pagination is stable for its
dataset cursor; direct reference or Domain scope narrows rather than
reinterprets the view. Neither `/importance` nor `/forecast` is an alias.

## Integrations, configuration, and hosts

| REPL command | CLI form | Meaning |
|---|---|---|
| `/import` | `lant import <source> (--snapshot\|--synchronize\|--migrate) [--erase-after-import]` | Run the catalog-declared Raw-first preflight and, after acceptance, import. |
| `/migrate` | `lant migrate --from <v0-jsonl> --into <v1-dataset>` | Produce the harmless v0 preflight plan; `--inspect`, `--build`, and `--cutover` are the only later stages. |
| `/export` | `lant export <exporter> [--scope <reference>] [--output <new-path>]` | Run one read-only Pack exporter; bytes go to stdout unless the host creates a new output file. |
| `/web` | `lant web` | Start the loopback-only local web mirror and display its expiring access URL. |
| `/config` | `lant config show\|paths\|validate\|connect` | Inspect or enter the typed configuration hub; `connect` previews one signed provider authorization while secrets remain under Vault. |
| `/profile` | `lant profile list\|show\|create\|use` | Inspect, create, or select one non-merging named profile. Profile removal is not a 1.0 command. |
| `/vault` | `lant vault unlock\|lock\|inventory\|add\|update\|remove\|rotate\|backup\|diagnose` | Manage the encrypted local credential vault without exposing plaintext. |
| `/packs` | `lant packs list\|show\|install\|updates\|update\|remove\|refresh\|trust\|untrust\|gc` | Manage verified Packs, trust, explicit catalog refresh, versions, and unreferenced archives. |
| `/editor` | host-mediated contextual action | Open only the current supported text draft in the configured external editor. |
| `/help [command]` | `lant help [command]` | Inspect canonical grammar and contextual recovery; it is distinct from `I don't [k]now`. |
| `/exit` | REPL only | End the presentation session without changing domain state. |

The exact REPL spelling `/quit` invokes `/exit`; it does not introduce a CLI
command or accept arguments. Outside editable input and filtering selectors,
an unmodified `q` is an undisplayed exit gesture when no current action owns
that shortcut. On the main opportunity screen, `Escape` returns through any
uncommitted local navigation first, then exits at its root. In editors,
palettes, lists, and nested previews it retains its cancel/back behavior.
Exiting retains the durable pending interaction and current focus; it does
not mean pause, done, or archive.

In the interactive REPL, `/done` and the current-focus `done` action advance
the committed completion result through its ordinary `next` continuation.
The successor shows `✓ Completed: <Brick citation>` until the next user
interaction; resize preserves it. A Work offer still requires Focus consent.
Repeatable return-policy questions retain their own continuation. The
noninteractive command returns its completion result without another draw.

An exporter's Lua code only returns validated bytes and metadata. With no
`--output`, the trusted host writes bytes to stdout. With `--output`, it may
create exactly one new regular file using exclusive creation; an existing
path, symlink target, missing parent, or nonregular destination is a typed
precondition error. Version 1.0 has no exporter overwrite flag, publisher,
automatic opener, or arbitrary Pack filesystem permission. The human may
rename or remove an old export outside Little Ant.

`lant packs install` accepts one official `name[@version]` from the currently
accepted signed catalog or one local `.lantpack` path. `lant packs refresh` is
the only catalog-network operation; it verifies the fixed official publication
and never installs or updates code. Both forms preserve the no-default consent,
dry-run, profile revision, and immutable-byte custody defined by UX-PACK00.
`lant packs update` accepts one installed official Pack name or one local
`.lantpack` candidate from an already trusted publisher and applies only the
complete reviewed UX-PACK01 pin and binding plan.

`lant packs remove <pack>` opens UX-PACK03 and removes only the selected
profile's preferred pin after exact references are classified. `lant packs gc`
opens the separate UX-PACK04 global archive plan. Neither has a default,
deletes canonical data, or performs implicit binding recovery; collection is
never automatic.

## CLI-only administration

These operations are intentionally absent from the ordinary slash palette:

| Command | Purpose |
|---|---|
| `lant tick` | Advance the same due temporal rules every ordinary command auto-ticks, without drawing or inventing Work. |
| `lant grammar [--screen <grammar>\|--json]` | Inspect the versioned interaction grammar used by every surface. |
| `lant doctor` | Diagnose configuration, log, projection, Pack, vault-permission, and environment health without repairing. |
| `lant repair` | Build and preview one typed local repair; it never silently edits history. |

Pack and migration subcommands remain under their named managers because they
are staged administrative protocols, not aliases for daily actions. Every
listed operation still obeys the same preview, stale-revision, typed-error,
credential, external-effect, and undo boundaries from chapters 7–9.

## Explicitly rejected vocabulary

The core rejects `/capture`, `/priority`, `/importance`, `/forecast`,
`/weight`, `/estimate-hours`, `/complete`, `/retire`, `/abandon`, `/kill`,
`/stop`, `/resume`, `/start`, `/edit`, `/plan`, `/find`, `/unify`,
`/interaction`, `/focus blocker`, and `/focus_blocker`. Natural-language
operators may understand the user's intent, but their visible result names
the canonical command above. This keeps old terminology and friendly language
at the boundary without making the core ambiguous.

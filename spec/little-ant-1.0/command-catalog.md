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
particular, there are no compatibility aliases. A rejected spelling receives
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

## Daily work and organization

| REPL command | CLI form | Meaning |
|---|---|---|
| `/next` | `lant next` | Obtain one replay-recorded opportunity without silently replacing current focus. |
| `/feed [text]` | `lant feed [text]` | Preserve one new item as Inbox Raw before any lazy classification. |
| `/focus [#brick]` | `lant focus <#brick>` | Ask the ordinary `Focus?` question for named Work, or resume its WIP continuation. |
| `/focus-blocker` | `lant focus-blocker <#brick>` | From a visible blocker chain, ask `Focus?` for its named executable blocker without claiming it started. |
| `/pause` | `lant pause` | End the current focus interval while retaining the Brick as WIP. |
| `/return-to-idle [#brick]` | `lant return-to-idle <#brick>` | Clear focus/WIP without claiming an outcome. |
| `/done [#brick]` | `lant done <#brick>` | Record the Nature-owned truthful completion outcome. |
| `/finish [#brick]` | `lant finish <#brick>` | Finish only an active checklist run; it is unavailable elsewhere. |
| `/archive [#brick]` | `lant archive <#brick>` | Stop pursuing Work without claiming completion. |
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
| `/search [query]` | `lant search <query>` | Search globally across typed references; `Ctrl-F` opens the same REPL route. |
| `/history [filters]` | `lant history [filters]` | Search bounded semantic history rather than dump the event log. |
| `/notices` | `lant notices` | Inspect current, acknowledged, and snoozed temporal notices. |
| `/translate [scope]` | `lant translate [scope]` | Run the interruptible English-normalization review queue. |
| `/undo [command-id]` | `lant undo [command-id]` | Append the declared compensation for one reversible action. |
| `/redo` | `lant redo` | Reapply the currently redoable intent when its preconditions still hold. |

`/list` has no default because its two views answer different questions. It
opens this dumb choice and then returns a bounded, pageable read-only view:

```text
List:

[i]mportance order
    The strict sibling tree settled by human judgment.

[f]ocus forecast
    Current chances and reasons used by next.

[?] I don't know

[/] more...
```

`importance` never renders a fake global score: it renders the composition
tree and strict order within each sibling group. `forecast` renders each
admitted attention subject's current positive chance, opportunity variant,
age, strongest signal, effective Domain path, and blocker endpoint. Neither
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
| `/help [command]` | `lant help [command]` | Inspect canonical grammar and contextual recovery; it is distinct from `[?] I don't know`. |
| `/exit` | REPL only | End the presentation session without changing domain state. |

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

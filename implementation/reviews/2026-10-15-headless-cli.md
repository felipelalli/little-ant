# CLI and skill review — 2026-10-15

## Problem and contract

The alpha executable could open an archive or update interaction but offered no
public way to answer it. Exit 0 meant the preview had opened, which could be
misreported as a completed mutation. The REPL had archive dispatch code but did
not offer it in the command palette. Its direct library access concealed the
missing response transport from internal engine tests.

The user authorized a complete review of the exposed CLI, non-interactive
operation, and matching repository/Codex/Claude operator skills. The normative
addition is the [headless interaction transport](../../spec/little-ant-1.0/command-catalog.md#headless-interaction-transport).
It realizes the common dispatcher in UX-001/004/033/039/279 without granting a
surface independent domain authority. This change does not claim completion of
deferred beta features.

## Audit of every exposed command family

All commands accept the global `--non-interactive` policy. Required missing
arguments fail; a question is returned as data rather than answered implicitly.
For guided rows, subsequent choices use `interaction respond --from FILE
--action ACTION_ID`, with exact text where required.

| Commands | Headless route and boundary |
|---|---|
| bare `lant` | With `--non-interactive`, fail with usage instead of starting the REPL. |
| `why` | Read-only recorded-selection inspection. |
| `next` | Return/record an opportunity; it can await an answer and is not a read-only query. |
| `feed` | Explicit text or piped stdin; reject a missing terminal value without prompting. Feed can complete while its returned triage question remains pending. |
| `show`, `list`, `search`, `help`, `history`, `grammar`, `doctor` | Direct query/diagnostic results; `--view guided show +RAW` opens that Raw's guided interaction. Use `list`/`why` when checkpoint preservation matters. |
| `done`, `return-to-idle`, `finish`, `pause` | Direct validated lifecycle operations, or their Nature-owned follow-up interaction. |
| `focus`, `focus-blocker` | Return the ordinary Focus proposal; answer `focus.accept` only within authorization. |
| `order`, `tie-break` | Return the real comparison/recovery route; only supplied human judgments are submitted. |
| `impact`, `effort`, `phase` | Return the actual class/comparison/evidence choices. The transport does not invent missing judgments. |
| `update` | Hub/field input and revision preview, or exact `title|description --text TEXT|--text-file FILE`; `--yes` accepts only that revision. |
| `break` | Submit the draft's text and answer the resulting classification/placement/preview actions. |
| `archive`, `restore` | Return the lifecycle preview, or complete it with `--yes`. No Focus acceptance is required. Archive retains its dependency-removal and relevance-review semantics. |
| `domain focus` | Return the existing Domain-focus choices. Other Domain-management subcommands are not exposed by this alpha parser. |
| `undo`, `redo` | Use the engine's existing compensation and conflict handling; transport grants no extra reversal authority. |
| `translate` | Return its actual scope/edit/preview/review actions; unsupported subpaths remain typed errors. |
| `import` | Explicit source, mode and containers; accept its exact preflight through the response transport. Source cleanup remains a separate authorized action. |
| `migrate` | Existing explicit inspection/build/cutover flags, with normal dry-run and retained backup semantics. |
| `export` | Explicit exporter/scope/output. Without an output file, preserve raw artifact bytes on stdout. |
| `packs list`, `show`, `updates`, `refresh` | Existing inspection/catalog operations; no terminal prompt. |
| `packs install`, `update`, `remove`, `trust`, `gc` | Return and answer exact Pack/trust/pin/component/collection previews through the common transport. One approval does not accept later trust/effect questions. |
| `profile list`, `show`, `create`, `use` | Existing explicit profile operations. Profiles do not merge. |
| `config show`, `paths`, `validate` | Existing redacted configuration queries. |
| `config connect` | Return provider consent. Static secrets can use explicit `--secret-stdin`; OAuth may still require external browser/provider approval, not terminal input. |
| `vault status`, `lock`, `inventory`, `backup`, `diagnose` | Existing explicit/redacted operations; backup destinations are new files. |
| `vault create`, `unlock`, `add`, `rotate` | `--secret-stdin` explicitly reads piped lines without echo. Create/rotate read the passphrase twice, unlock/add once. Without a secret source, non-interactive calls fail before prompting. |
| `vault remove` | Keep its existing exact UUID and explicit `--yes` requirement. |
| `tick`, `notices` | Existing temporal operation or pending notice choices; no terminal automation. |
| `repair` | Existing repair preview and bound response path, including the recovery-only corrupt-history route. |
| `merge`, `supersede`, `web`, `editor`, `packs untrust` | Already return typed `unsupported`; the new flag does not pretend to implement these deferred capabilities. |
| `interaction show`, `respond`, `back`, `forward` | New public, revision-bound transport for all implemented guided actions and input/navigation. No REPL scraping or direct event/checkpoint edits. |

The private vault-agent process switch is an internal process protocol, not an
additional public operation. Secret bytes are never supplied in argv, JSON
envelopes, public results, or skill files.

## Result and stale-response behavior

CLI JSON results identify `completed`, `awaiting_input`, or `simulated` status.
Non-interactive exit codes distinguish success/inspection/dry-run (0), a pending
answer (2), and an error (1). A completed operation can carry a follow-up
interaction. A read of the pending question exits 0 even when that question
awaits input. Legacy preview-opening calls without the flag retain exit 0.

Responders supply the original result or envelope, its exact action ID, and
optional text. A modified envelope, wrong action, missing text, stale response,
or attempted replay does not become consent to the current question. Relevant
dataset changes reject old answers; unrelated changes may be revalidated under
UX-192. Callers inspect state/history after uncertain mutation outcomes.

The [shared checkpoint concurrency defect](../adr/0003-persisted-guided-checkpoints.md#current-alpha-concurrency-limitation)
remains an explicit limitation. This transport does not isolate simultaneous
sessions or repair concurrent checkpoint publication.

## Validation scope

`test/e2e/headless.py` invokes the executable in isolated XDG profiles using only
public commands. It covers creating Work, archive/restore/update without Focus,
bound input and navigation, stale/replayed/tampered answers, exact multiline
text, byte-preserving dry-run, import confirmation, judgment/Focus/completion,
unsupported commands, explicit redacted vault input, and refusal to prompt even
when stdin is a real terminal.

`test/e2e/repl.py` also covers discovery and execution of `/archive #handle`,
the bare `/restore` target selector, confirmation, and unchanged Focus history.
The full CI gate includes both suites. These tests prove the transport and
representative end-to-end operations; they do not close the beta's complete
surface-parity or provider/live-integration gates.

---
name: little-ant
description: Operate Little Ant (lant) when the user wants to capture intentions, find or inspect tasks, browse importance or forecast, choose a focus, or complete work in their LANT dataset. Use the installed CLI and its actual choices. Repository development alone does not require this skill.
metadata:
  compatibility: lant 1.0.0-alpha.2
---

# Little Ant operator

This is an operator for the alpha CLI. Full v1 assisted-surface parity remains
beta work. Obtain commands, choices, and consequences from the running engine;
do not recreate its lifecycle, importance order, or selection algorithm.

## Establish the executable and profile

Check `command -v lant`, `lant --version`, and `lant --help`. This skill ships
with `lant 1.0.0-alpha.2`; an older executable cannot fully read the current
hot/cold event layout. Resolve an installation mismatch before operating on a
dataset. Do not fall back to the retired executable or a review launcher.
The installed help must also expose `--non-interactive` and `interaction`;
the prerelease version alone does not prove those routes are installed.

Use `lant --json profile show` to identify the selected profile and dataset.
Honor a profile named by the user; otherwise keep the selected profile. Pass
`--profile NAME` on subsequent commands. Profiles do not merge. A repository
checkout does not select a test dataset.

## Share a dataset with another client

The alpha stores one pending interaction and navigation history per dataset,
shared by the skill, CLI, and REPL. Dumb mode does not isolate sessions. A
guided route or mutation can replace another tab's pending question, and the
other REPL will not refresh automatically.

When another client is driving a flow, prefer `list importance`, `list forecast`,
or `why`, which preserve that interaction. Coordinate a handoff before driving
guided decisions or changes in the other client; `next` is not a read-only query.
Read any refreshed question before submitting another answer.

Canonical event writes are locked and cursor-validated, but concurrent
presentation checkpoint saves are not yet protected. They can overwrite pending
navigation or fail with a checkpoint write/read error. Do not promise independent
simultaneous guided sessions. After an uncertain result, follow the state/history
inspection guidance below before retrying.

## Query before deciding

Use `--non-interactive --json --schema 1` so no operation opens the REPL or
prompts on the terminal. Start with the
smallest relevant query and use the references it returns:

| User intent | CLI route after `lant --profile NAME --non-interactive --json` |
|---|---|
| Find a task or Raw | `search 'query'` |
| Inspect a returned reference | `show '#handle'` |
| Inspect its description and context | `--view operational show '#handle'` |
| Open the workflow for one exact Raw | `--view guided show '+handle'` |
| Browse human importance | `list importance` |
| Browse selection chances without drawing | `list forecast` |
| Explain the current recorded selection without drawing | `why` |
| Obtain or restore the next opportunity | `next` |
| Inspect recent changes | `history 5` |
| Check dataset consistency | `doctor` |

Quote typed references such as `'#handle'` and `'+raw'` in shell commands.
Resolve ambiguous references through search; do not guess a target from a
partial title. Keep importance positions, forecast probabilities, and human
confidence distinct. Report the engine's result rather than inventing a
ranking or claiming the selected Brick is necessarily the best one.

`why` explains the selection attached to the pending interaction; use
`--view complete why` for recorded calculation details. It never redraws or
answers a comparison. Old records may lack factor/probability snapshots.
Forecast rows separate the subject total from Work and ordering-review shares;
these are opportunities of one subject, not additional task tickets.
Effort, impact, and impact-evidence reviews require explicit demand or a material
change to already-judged scope/evidence. An empty field alone creates no review.
Opening `/effort` or `/impact` starts immediate help and can persist an unresolved
request. Review skip cools equivalent questions for 24 hours, preserving Work.
Never answer those comparisons or classify a Brick on the user's behalf.

`next` can record a selection and presentation checkpoint. Use `list forecast`
for a probability question, and `--dry-run next` for an explicitly requested
preview. A dry-run result is a simulation, not a committed selection.

## Perform the requested operation

For an authorized capture, pass the user's original material through stdin to
`lant --profile NAME --json feed`, or as a properly shell-quoted argument.
Feed saves Raw material; it does not by itself create a fully triaged Brick.

English is the canonical language of Brick titles (PRD-010), whatever language
the conversation uses. When triage asks for a title, propose an English one
and submit it only once the user accepted it; never submit a title in another
language on your own. Raw material keeps the user's original words.

For an authorized completion, resolve the exact Brick, then use
`lant --profile NAME --json done '#handle'`. Prefer the explicit reference over
bare `done`, which completes the current focus. Verify the returned result and
inspect the Brick's status when needed. Preview a proposed mutation with the
global `--dry-run` flag; do not report its simulated success as a saved change.

Some commands return an `interaction` with `content`, `actions`, `commands`,
and revision/cursor information. Present the actual pending choice. For
example, `focus '#handle'` opens a proposal; it does not mean Focus was accepted.
Importance comparisons, readiness judgments, and missing decisions belong to
the user. Existing authorization applies to the operation it covers.

For an authorized archive or restore, use `archive '#handle' --yes` or
`restore '#handle' --yes` with the common profile/non-interactive/JSON flags.
These accept only the exact lifecycle preview created by that invocation,
without putting Work in focus. Archive also removes the previewed dependencies
and creates one relevance review. Inspect the preview first when needed to
understand its effects. Verify the resulting lifecycle before reporting success;
a description saying "archived" is not lifecycle evidence.

For an authorized exact text revision, use `update '#handle' title|description
--text TEXT --yes`, or `--text-file FILE` (`-` for piped stdin) to preserve
multiline text. Omitting `--yes` leaves the revision preview pending.

A recurring-obligation series releases nothing until it has a recurrence.
`update '#handle' repetition` opens its structured editor (family, occurrence
Nature, interval, weekdays or day, local times, IANA zone, and the opens,
best-before, and deadline offsets such as `4 days before` or `at the
anchor`); answer each field through `interaction respond`, then confirm the
previewed anchors with the user before `recurrence.accept`. With a deadline,
`At deadline` asks whether an unfinished period stays open as debt (a bill) or
counts as missed (a required shift); the latter takes an optional consequence
of at most 200 characters. `--view guided show '#occurrence'` opens one
occurrence: a missed one offers `occurrence.done_late` and
`occurrence.excuse`, an open one `occurrence.excuse`. Never choose done late
or excuse for the user.

For any other implemented guided flow, save its actual JSON result. Use
`interaction show` to inspect the current saved question without drawing or
changing its checkpoint. Submit one actual action ID with `interaction respond
--from FILE --action ACTION_ID`; input actions additionally accept `--text TEXT`
or `--text-file FILE`. `--from -` accepts a piped envelope/result, but cannot
share stdin with `--text-file -`. Use `interaction back|forward --from FILE`
for bound presentation navigation. Keep the original envelope fields intact.

Each response validates identity, revision, cursor, token, and current
preconditions. A stale/replaced question returns `stale_interaction`; inspect
the current state and reopen the original route when needed, then obtain the
user's answer to that question. Do not carry consent to its replacement, invent
comparison judgments, or loop through affirmative answers. Invoke canonical
commands for presentation controls such as Feed and the palette. Never automate
the REPL, use internal Haskell APIs, or edit canonical data/checkpoints.

## Errors and experimental routes

Check the exit status and parse structured errors from stderr, including
`code`, `recovery`, and `retry_safe`. After a timeout or uncertain mutation,
inspect current state/history before retrying. Refresh stale interactions;
do not reuse an old action against a changed screen.

With `--non-interactive`, exit 2 is a valid JSON result with
`status: awaiting_input`, not an applied operation or an error. Present the
pending choice or answer it within existing authorization. Exit 0 means success
or simulation; inspect `status` and `dry_run`. `interaction show` exits 0 for
successful inspection even if the question awaits input. A completed command
may include a follow-up question. Exit 1 is an error; never claim completion
from a preview or from exit 0 on an older binary.

Vault/static-provider secret input uses explicit `--secret-stdin` and piped
lines, never secret arguments or echoed terminal automation. Vault creation and
rotation consume the new passphrase twice; unlock/add consume one secret.
Browser-based provider authorization still needs the account owner's external
approval. A missing secret source fails rather than prompting in non-interactive
mode. Avoid putting secrets in conversation text, skill files, or logs.

Use the installed command's `--help` before an unfamiliar route. Experimental
commands may still return `unsupported`; report that boundary accurately.
Powered-up mode and local web are not completed by installing this skill.

For HTML export, use `export html --output NEW_FILE` with a new destination.
The exporter is experimental and read-only with respect to the dataset. With
`--output`, the normal JSON result describes the generated artifact; without
it, an export can emit raw file bytes instead of JSON.

For Microsoft To Do, inspect the configured source and `import --help` before
an explicitly requested import. Import is not bidirectional synchronization.
Source deletion through `--erase-after-import` requires authorization that
specifically covers deleting the remote items. Keep credentials in the LANT
vault/configuration flow, outside conversation text and skill files.

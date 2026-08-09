# ADR 0031: Ship Apple Reminders as an offline Shortcut kit

## Status

Accepted.

## Context

Apple Reminders is platform-owned. EventKit exposes reminder identity and due
date components, but a portable sandboxed Lua Pack cannot receive native
EventKit authority. A fabricated `.shortcut` plist would neither be an
inspectable source of truth nor an Apple-signed installable workflow.

The standard catalog therefore promises an offline export kit, snapshot and
migration only, with no source cleanup or live synchronization. Repeated
imports still need stable list/reminder identities, and source completion must
remain observation rather than local Work outcome.

## Decision

The signed standard Pack contains:

- a closed `little-ant/apple-reminders-export@1` JSON Schema;
- one reviewed example export;
- an inspectable, read-only Shortcut action recipe; and
- the `apple_reminders_export` SourceAdapter.

The recipe requires the identifiers exposed by the Apple Reminder and
Reminders List values. It must not derive identity from mutable titles or array
positions. The flat export repeats list identity on each reminder so the
Shortcut does not need hidden grouping logic; the adapter reconstructs sorted
source containers and rejects conflicting list titles or duplicate reminder
identifiers.

The adapter is selected by the specific `.apple-reminders.json` suffix before
the generic `.json` document adapter. It accepts only snapshot/migrate,
validates the closed non-null contract, and preserves every reminder as
canonical `little-ant/apple-reminder@1` structured Raw. Completion, due data,
priority, URL, tags, and flag state remain source facts; import does not adopt
Work or create temporal semantics.

The portable recipe does not export recurrence rules, subtasks, attachments,
or location alarms. Preflight states that limitation. The kit includes no
credential and makes no provider request or source mutation.

The private runner gains a pure bounded `lant.json.decode` helper. It rejects
invalid JSON and JSON null before converting to Lua, preventing null fields
from silently disappearing as Lua `nil`. Format-specific validation remains in
the signed adapter, not Haskell core.

## Consequences

- An Apple user can audit and build the workflow locally without entrusting a
  secret or granting Little Ant native platform access.
- The repository does not claim that an unsigned generated plist is an
  installable Apple Shortcut.
- Exact repeated exports retain stable SourceBindings while mutable content
  remains reconcilable Raw truth.
- A Shortcuts version that cannot expose Apple identifiers cannot satisfy this
  V1 contract; failing explicitly is safer than creating unstable duplicates.

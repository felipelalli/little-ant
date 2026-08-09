# Standard integration catalog

Status: **Little Ant 1.0 release catalog**

This catalog closes what 1.0 actually ships. “Supported” does not pretend that
every source has the same API. Each row names the strongest honest mode.

## Distribution

The **offline standard Pack** is installed with Little Ant and needs no
provider account. It contains:

- file SourceAdapters for plain text, Markdown, HTML, JSON, CSV, Org, Evernote
  ENEX, Notesnook Markdown/HTML/plain-text ZIP exports, and TaskJuggler actuals;
- the tree-text, aligned-table, RFC 4180 CSV, Org, self-contained HTML, and
  TaskJuggler ReadOnlyExporters;
- the declarative factory Natures and Templates; and
- the `local_web` UIAdapter.

The **official connector Pack** is a separately installed and pinned Pack from
the official catalog. It contains provider or platform-specific SourceAdapters
for Microsoft To Do, Google Tasks, Google Calendar, and GitHub Issues. Its
manifest is inspectable before installation and requests credentials only when
one of its components is configured.

V1 publishes that Pack as `org.littleant.official-connectors@1.0.0`. After an
explicit `lant packs refresh`, `lant packs install
org.littleant.official-connectors` resolves its exact catalog digest and opens
the ordinary no-default authority preview. Refresh does not install it, and
the Pack receives no provider credential until a separately reviewed account
connection binds one declared slot.

Apple Reminders support is an offline import kit in the standard Pack: an
inspectable Apple Shortcut exports reminder lists as versioned JSON, and the
file SourceAdapter consumes those bytes. It is snapshot/migration support, not
live synchronization. The Shortcut never receives a Little Ant vault secret.

## Source capabilities

| Source | 1.0 input | Modes | Source cleanup after verified migration |
|---|---|---|---|
| Microsoft To Do | Microsoft Graph | snapshot, synchronize, migrate | item deletion; empty-list deletion is separate |
| Google Tasks | Google Tasks API | snapshot, synchronize, migrate | item deletion; empty-list deletion is separate |
| Google Calendar | Google Calendar API | snapshot, synchronize | no migration erase; reviewed event create/update/cancel is the separate Calendar write-back path |
| GitHub Issues | GitHub REST API | snapshot, synchronize | unsupported; closing an issue is not deletion and is never substituted for it |
| Apple Reminders | Pack-supplied Shortcut JSON | snapshot, migrate | unsupported in 1.0 |
| Notesnook | exported Markdown, HTML, or plain-text ZIP | snapshot, migrate | unsupported in 1.0 |
| Evernote | ENEX or HTML export | snapshot, migrate | unsupported in 1.0 |

`--erase-after-import` is accepted only when the selected SourceAdapter
declares the exact cleanup capability in this table. Otherwise preflight fails
before import with `unsupported` and suggests an ordinary verified migration.

Microsoft To Do and Google Tasks expose official list, task, and delete
operations. Google Calendar exposes event list, instance, create, update, and
delete operations. GitHub exposes issue management but not issue deletion as a
normal Issues API operation. Apple EventKit supports native reminder access,
but a portable Lua Pack cannot acquire that platform authority; the explicit
export kit keeps the 1.0 Pack boundary honest. Notesnook officially exports
Markdown, HTML, and plain text, while Evernote officially exports ENEX and
HTML.

Primary platform references:

- [Microsoft To Do API overview](https://learn.microsoft.com/en-us/graph/todo-concept-overview)
- [Google Tasks REST API](https://developers.google.com/workspace/tasks/reference/rest)
- [Google Calendar Events API](https://developers.google.com/workspace/calendar/api/v3/reference/events)
- [GitHub Issues REST API](https://docs.github.com/en/rest/issues)
- [Apple EventKit reminders](https://developer.apple.com/documentation/eventkit/retrieving-events-and-reminders)
- [Notesnook export formats](https://help.notesnook.com/export-notes-from-notesnook)
- [Evernote ENEX/HTML export](https://help.evernote.com/hc/en-us/articles/209005557-Export-Notes-and-Notebooks-as-ENEX-or-HTML)

## Import defaults

Every source object is first preserved as Raw material with a SourceBinding or
immutable file-import provenance. Imported task lists, repositories,
notebooks, and calendars create source-derived RawShelf suggestions; they do
not silently become Domains, parent Bricks, or local completion truth.

Task-shaped sources may offer a separate, explicit bulk-adoption preview after
verification. The preview is only a compact route into the ordinary Raw
triage and Work-materialization rules. Rejection leaves all imported Raws
intact. Mixed note exports have no bulk Work default.

## UIAdapter boundary

`local_web` is the only UIAdapter shipped in 1.0. A first-party host serves its
static assets and canonical InteractionEnvelopes on loopback only, using an
unguessable session token, origin checks, and no provider credentials in the
browser. It cannot be bound to a non-loopback address in 1.0. The adapter maps
one displayed revision and action ID back to the canonical dispatcher and
therefore mirrors—not reinterprets—the dumb REPL.

Remote chat, email, and mobile-channel UIAdapters may live in the community
catalog but are not 1.0 release promises. First-party mobile remains a later
surface over the same protocol, not a Pack capability.

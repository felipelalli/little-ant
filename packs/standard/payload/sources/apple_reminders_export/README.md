# Apple Reminders offline export kit

This SourceAdapter imports a versioned JSON file produced by the inspectable
Shortcut recipe in `shortcut-recipe.md`. It supports snapshot and migration;
it never receives an Apple or Little Ant credential, changes Reminders, or
claims live synchronization.

The repository intentionally does not pretend that a generated plist is an
installable Apple-signed Shortcut. Build the workflow on an Apple device from
the signed recipe, compare its output with `export.schema.json` and
`example.apple-reminders.json`, then save the result with the suffix
`.apple-reminders.json`.

Every reminder is preserved as structured Raw material. Apple list and
reminder identifiers provide repeatable source identity. A device whose
Shortcuts version cannot expose those identifiers cannot produce this V1
contract and must not invent IDs from titles or array positions.

Recurrence rules, subtasks, attachments, and location alarms are outside this
portable Shortcut contract. The preflight reports that limitation explicitly.

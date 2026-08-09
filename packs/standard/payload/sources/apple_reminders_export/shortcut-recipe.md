# Shortcut recipe: Export Reminders for Little Ant

Create a Shortcut named **Export Reminders for Little Ant**. The workflow is
read-only and contains these visible stages:

1. Use **Find Reminders** with no limit and include both open and completed
   reminders.
2. Create an empty `reminders` list variable.
3. Repeat with each reminder. Read its Identifier, Name, Notes, Is Completed,
   Completion Date, Due Date, Priority, URL, Tags, Flagged state, and Reminders
   List. Read the list's Identifier and Name.
4. If a Due Date exists, format it as ISO 8601. Record `due_kind` as `date` for
   an all-day due date or `instant` when the reminder has a due time. Omit both
   due fields when no Due Date exists.
5. If a Completion Date exists, format it as ISO 8601 and record it as
   `completed_at`. Omit it otherwise.
6. Build one Dictionary using the field names in `export.schema.json`. Always
   include `id`, `list_id`, `list_title`, `title`, and `completed`; include the
   optional fields only when Reminders supplies them. Add the Dictionary to
   the `reminders` list.
7. After the repeat, build the top-level Dictionary with schema
   `little-ant/apple-reminders-export@1`, the current date formatted as ISO
   8601 in `exported_at`, `apple_identifier` in `identity_strategy`, the
   optional device name, and the `reminders` list.
8. Convert the Dictionary to JSON and save it as
   `reminders.apple-reminders.json`. Do not send it over the network.

Before migration, inspect the JSON as text. The Shortcut must request only
read access to Reminders and permission to save the chosen file. It must not
call a URL, run a script, delete a reminder, or receive a Little Ant secret.

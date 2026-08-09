# Google Tasks SourceAdapter

This official connector reads Google task lists and tasks through Little Ant's
host-brokered HTTPS boundary. It supports `snapshot`, `synchronize`, and
`migrate`, preserves each selected task as complete structured Raw material,
and retains stable account/list/task source identity.

Configuration can restrict exact task-list IDs and can include completed and
hidden completed tasks. Assigned tasks are deliberately excluded: deleting an
assigned Google Task can also delete its original task in Docs or Chat, which
is wider authority than V1 migration cleanup promises.

The account supplies a public OAuth client ID created for a desktop
application. The signed component fixes Google's authorization and token
endpoints, the Google Tasks scope, `access_type=offline`, and `prompt=consent`.
The trusted host owns the external browser, PKCE verifier/challenge, loopback
callback, token exchange, refresh, and encrypted vault persistence. Lua never
receives any OAuth secret.

Migration cleanup is itemwise and separately approved after local Raw
verification. Empty task-list deletion is a later independent approval. The
adapter resolves Google's `@default` list before every container-cleanup
proposal and protects it even when Google returns an opaque concrete ID.

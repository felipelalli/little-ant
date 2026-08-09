# Microsoft To Do SourceAdapter

This official connector reads Microsoft To Do lists and tasks through the
host-brokered Microsoft Graph boundary. It supports `snapshot`, `synchronize`,
and `migrate`, preserves every selected task as structured Raw material, and
retains stable account/list/task source identity.

Configuration can select list IDs and include completed tasks. The host owns
OAuth, injects `Tasks.Read` or `Tasks.ReadWrite` credentials outside Lua, and
never exposes a bearer token to this component. Cleanup requires
`Tasks.ReadWrite`, verified local import, and the separate item/container
effect approvals.

The account configuration supplies one public Microsoft application
`client_id`. The signed component fixes the Microsoft device-authorization and
token endpoints plus the least-authority `Tasks.Read offline_access` scope set.
The resulting grant is fingerprint-bound to that exact client ID, signed Pack
identity, slot, endpoints, and scopes; changing any of them requires fresh
human consent.

Microsoft Graph can report `hasAttachments` without returning attachment
bodies in the task collection. The connector records this as an explicit
unsupported-field warning. `migrate` refuses such a partial source unless the
human explicitly enables `allow_incomplete_attachments`; snapshot and
synchronize preserve the task while keeping the limitation visible. This
guard must remain until attachment bodies traverse a separately bounded,
verified materialization path.

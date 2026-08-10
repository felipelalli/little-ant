# Google Calendar SourceAdapter

This official connector observes explicitly selected Google calendars through
Little Ant's host-brokered HTTPS boundary. It supports `snapshot` and
`synchronize`; it never edits or deletes Calendar data.

Container discovery lists readable calendars without reading any event. A real
import receives an exact nonempty calendar allowlist from the trusted host and
returns events only from those containers. Each event is preserved as complete
structured Raw material together with its calendar, account, recurring-series,
original-occurrence, all-day, time-zone, cancellation, and attachment data.

The account supplies a public OAuth client ID created for a desktop
application. The signed component fixes Google's authorization and token
endpoints, the `calendar.readonly` scope, `access_type=offline`, and
`prompt=consent`. The trusted host owns the browser, PKCE verifier/challenge,
loopback callback, token exchange, refresh, and encrypted vault persistence.
Lua never receives an OAuth secret.

Calendar write-back is intentionally absent. A future write-back component must
declare separate authority and pass a separate per-calendar review.

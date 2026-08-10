# GitHub Issues SourceAdapter

This official connector observes issues visible to one GitHub account through
Little Ant's host-brokered HTTPS boundary. It supports `snapshot` and
`synchronize`; it never closes, edits, or deletes GitHub content.

The credential slot accepts a GitHub fine-grained personal access token. Give
the token access only to the repositories to observe and grant repository
**Issues: read-only** permission. Little Ant collects the token through a
dedicated no-echo Vault input; it must not appear in arguments, environment
variables, YAML, canonical events, Pack input, or interaction state. The
trusted host injects it only after checking this signed component's exact
`GET https://api.github.com/issues` authority. Lua never receives the token.

Open issues are included by default. Optional account configuration may set
`include_closed` to `true`. GitHub's cross-repository issues endpoint can also
return pull requests; the adapter identifies and omits those records rather
than pretending that they are issues. Every retained issue is preserved as
complete structured Raw material with its repository and stable GitHub node
identity.

GitHub Issues has no cleanup path in Little Ant 1.0. Closing an issue changes
workflow state and is never substituted for deletion after migration.

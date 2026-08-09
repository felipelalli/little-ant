# Evernote ENEX SourceAdapter

This offline adapter accepts one UTF-8 Evernote ENEX export in `snapshot` or
`migrate` mode. Each complete `<note>` element becomes one note-shaped Raw, so
its ENML content, attributes, recognition data, and base64 resource payloads
remain together rather than being lossily converted.

The note GUID is used when present. Otherwise the digest of the complete note
element provides deterministic identity for repeated imports. Resource
elements are counted as attachments but remain preserved inside the ENEX Raw.
The adapter has no live presence inference or cleanup capability.

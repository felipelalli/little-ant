# Notesnook export SourceAdapter

This offline adapter accepts one Notesnook-style ZIP export in `snapshot` or
`migrate` mode. Each UTF-8 Markdown, HTML, or plain-text file is preserved as a
separate note-shaped Raw with its relative path as stable source identity.
Directories are reported as source containers so the ordinary import preview
can suggest shelves without creating them silently.

Other archive entries are reported but not imported. The adapter cannot erase
Notesnook data, infer live source absence, create Work, or synchronize an
exported file. Complete note bodies cross the isolated runner boundary only
during the post-consent materialization pass; the persisted preflight contains
bounded summaries.

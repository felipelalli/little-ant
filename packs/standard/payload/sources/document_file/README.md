# Document file SourceAdapter

This offline adapter preserves one UTF-8 Markdown, HTML, JSON, CSV, or Org file
as one Raw object in `snapshot` or `migrate` mode. It does not convert, render,
or reinterpret the document; the exact text remains the accepted material.

The media type selects the visible format and note-shaped versus generic Raw
hint. Source identity and duplicate suspicion use the complete input digest.
The adapter has no live presence inference or cleanup capability.

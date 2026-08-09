# ADR 0030: Preserve offline documents before interpretation

## Status

Accepted.

## Context

The 1.0 standard catalog promises offline import for Markdown, HTML, JSON, CSV,
Org, and Evernote ENEX. These formats can contain useful structure, but turning
that structure directly into Bricks, Domains, or normalized prose would make a
format parser into hidden product judgment. Mixed note systems additionally
require lazy Raw triage rather than guessed Work.

## Decision

The signed standard Pack ships one `document_file` SourceAdapter for the five
single-document UTF-8 formats. It uses the host-supplied media type to name the
format and suggest only `note` versus `other` shape. The accepted SourceMaterial
is the exact decoded text; the adapter does not render, canonicalize, translate,
or reinterpret it. Complete input SHA-256 is both source identity evidence and
a duplicate-suspicion key.

Evernote ENEX remains a separate multiobject SourceAdapter. It deterministically
extracts each complete `<note>` element, uses the exported GUID when present or
the complete element digest otherwise, and preserves that whole XML element as
Raw text. Embedded resource elements stay inside the preserved note material
and are counted as attachments; the adapter does not perform lossy ENML or
resource conversion.

File selection uses the longest matching lowercase suffix. This keeps ordinary
`.json` unambiguous while allowing a later versioned format such as
`.apple-reminders.json` to select a more specific adapter without an alias or a
content guess in core.

## Consequences

- Offline import remains useful and searchable without making conversion a
  precondition for preservation.
- Repeated identical files and ENEX exports reuse deterministic source-object
  identities through the generic import contract.
- Structural interpretation can happen later through explicit triage or
  assisted proposals without changing source truth.
- Invalid UTF-8 or malformed ENEX fails before mutation; no best-effort partial
  conversion is presented as complete import.

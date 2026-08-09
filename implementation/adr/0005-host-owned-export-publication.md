# ADR 0005: Host-owned export publication

## Status

Accepted for the S09 export-host milestone.

## Canonical constraints served

- DAT-028 keeps exporters read-only and limits their result to bytes and
  declared metadata.
- DAT-092 and UX-282 keep paths and filesystem authority in the trusted host,
  reject unsafe destinations before exporter invocation, prohibit overwrite,
  and leave no partial target after failure.
- DAT-029 and DAT-030 keep the shipping serializers in the standard Pack; the
  Haskell core owns projection construction and validation, not those output
  formats.

## Considered physical designs

Writing directly to an exclusively created target would prevent overwrite but
could expose a partial target after interruption. Writing a temporary file and
using ordinary rename could overwrite a target created during exporter
execution. Implementing the standard formats directly in Haskell would bypass
the Pack boundary even if the visible bytes were correct.

## Decision

`AppEnv` owns an injected `ExportPort`. Its invocation receives only an
`ExportDescriptor` and the versioned `little-ant/structure@1` projection; its
type contains no output path or filesystem capability. Production uses an
empty port until the verified Pack registry supplies installed components.

For a requested file, the host validates the absent target and its real,
existing, non-symlinked parent before invoking the exporter. After validating
the returned bytes and metadata, it writes and synchronizes a private
same-directory temporary regular file, publishes it with an atomic no-clobber
hard link, synchronizes the parent, and removes the temporary name. Stdout
bytes remain an internal result field and are never copied into structured
JSON.

This boundary is intentionally independent of Lua and Pack discovery. The Pack
runtime can replace the empty port without changing command dispatch,
projection construction, destination validation, or publication semantics.

## Verification

`little-ant-s09-export-test` proves deterministic sparse projection, exact
stdout/file bytes, digest and permissions, dry-run, read-only replay, rejection
before invocation for existing/symlink/nonregular/missing-parent targets,
cleanup after exporter failure, invalid metadata rejection, and closed
exporter-registry errors.

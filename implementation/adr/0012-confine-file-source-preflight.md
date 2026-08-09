# ADR 0012: Confine file-source preflight to host-custodied bytes

## Status

Accepted for S09.

## Context

The public 1.0 grammar has one positional `<source>` and three explicit import
modes. It does not define an `--input` option. File SourceAdapters nevertheless
need to inspect user-selected material without receiving ambient filesystem
authority, while import acceptance later needs a reproducible preflight that
can detect changed input.

Passing a path into Lua would let Pack code infer or probe host filesystem
structure. Running an importer in the main process would also bypass the Pack
resource and library restrictions already established for exporters.

## Decision

The trusted host reads a selected file under its own policy and invokes a
`SourceAdapter` with only:

- the exact input bytes;
- a non-authoritative display label and media type;
- the host-computed SHA-256 digest and byte count; and
- the explicit requested import mode.

The Pack receives the bytes through `lant.input_bytes()` inside the existing
fresh private HsLua process. It receives no path, file handle, directory, or
general IO primitive. The runner accepts this invocation only for an
execution-authorized `SourceAdapter` that declares `input_bytes`; exporters
cannot receive input bytes.

Lua returns one closed, typed observation containing source/account labels,
supported modes, cleanup capability, containers, objects, source shape,
completion observation, attachment count, a bounded material summary with its
digest, duplicate-suspicion keys, unsupported fields, and warnings. The runner
validates and canonically encodes that observation without echoing source bytes
back across the process boundary. The host then joins it to the exact Pack
identity, signer, component contract, canonical permissions, requested mode,
and input custody facts as
`little-ant/source-preflight@1`. Unsupported modes fail before canonical
mutation.

For the initial file boundary, the public `<source>` token is the input path.
The host must resolve it to exactly one enabled adapter before execution. The
standard registry maps `.txt` and `.text` to `plain_text`; an unknown or
ambiguous format fails instead of guessing. Extension resolution selects an
adapter only—it never invents supported modes or cleanup authority. The host
rejects symbolic links and non-regular files, enforces a 64 MiB ceiling before
and after reading, opens with `O_NOFOLLOW`, and hashes the bytes obtained from
that opened descriptor.

The first standard component, `plain_text`, identifies the entire UTF-8 file
as one note-shaped source object for Raw preservation. It supports snapshot
and migration but no live observation or cleanup. `/import` persists the
complete preflight as a read-only checkpoint, reacquires the file through the
same boundary on acceptance, and refreshes a stale preview without canonical
mutation.

## Consequences

- Pack code cannot enumerate or reopen a user's filesystem;
- replay never invokes a SourceAdapter or needs the Pack installed;
- a later acceptance can rerun preflight and compare the exact input and Pack
  custody facts before committing;
- source modes and cleanup remain adapter-declared facts rather than filename
  guesses;
- the public command grammar remains frozen while the REPL can still collect
  source and input in separate screens;
- binary material remains represented by a typed kind, exact digest, byte
  count, and bounded preview; a later accepted import reruns against the same
  custody facts before the host preserves bytes.

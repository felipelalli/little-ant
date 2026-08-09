# ADR 0009: Isolate HsLua Pack execution

## Status

Accepted for S09.

## Context

Read-only exporters are signed Pack components, but their Lua source is still
untrusted executable input. Running it inside `lant` would share process
memory, failure scope, runtime limits, and accidental host capabilities with
the deterministic core. Passing an output path to Lua would also let a
serializer become a filesystem effect.

## Decision

`lant` invokes a private `lant-pack-runner` helper for every exporter call.
The release package installs only `lant` in `bin`; the helper lives under
`libexec/little-ant`. Each invocation receives one bounded RFC 8785 JSON
request on stdin and emits one bounded canonical response on stdout. Binary
payload and artifact fields use canonical unpadded base64url. The protocol
contains projection data and the execution-authorized component payload, never
an output path, credential, provider response, or host handle.

The helper starts a fresh HsLua VM. It exposes only the base, math, string, and
table libraries after removing dynamic loading, bytecode generation,
nondeterministic random functions, process output, and garbage-collector
control. `require` and `lant.asset` resolve only signed files inside the
component payload. Entry points must be UTF-8 Lua source rather than bytecode,
return one function, and return exactly `bytes`, `media_type`,
`suggested_filename`, `warnings`, and `metadata`.

The parent owns a five-second wall ceiling, bounded request/response/artifact
sizes, pipe draining, process-group termination, and artifact validation. The
child additionally applies CPU, address-space, file-size, core-size,
open-file, stack, and GHC RTS limits. The address-space ceiling is bounded
additional space above the freshly measured runtime baseline: GHC's initial
virtual reservation varies between development, profiling, and distribution
links and is not Pack memory. The helper is non-threaded because a tight
address-space limit and the threaded RTS reserve/worker startup conflict before
Lua executes.

`PackRunnerClient` is the replacement seam. Tests may inject an exact helper
path and stricter limits, but no configured limit may exceed the factory
ceiling.

## Consequences

- a Lua loop, exception, oversized response, or malformed result cannot crash
  or mutate the event authority;
- every call pays process and fresh-VM startup cost, acceptable for explicit
  export and adapter operations;
- a signed component still receives only the payload slice and projection
  authorized by the registry;
- output publication remains a separate host-owned atomic operation;
- the private helper is an implementation component, not a second public CLI.

# TaskJuggler exporter contract

This standard-Pack component serializes the core-owned
`little-ant/taskjuggler@1` projection. It does not choose the planning cut,
interpret effort, invent missing estimates, read the dataset, or perform I/O.

The generated `.tjp` embeds two distinct custody values:

- `LANT-MANIFEST-SHA256` identifies the canonical immutable planning manifest;
- the host's export digest identifies the complete serialized artifact.

The numbered `LANT-MANIFEST-JCS-BASE64URL-*` comment lines contain the complete
unpadded base64url encoding of that canonical manifest. A future actuals
SourceAdapter must reconstruct it in sequence, verify its SHA-256 digest, and
fail closed when the custody comments are absent, reordered, malformed, or
changed. It must not infer identity from the final artifact digest.

Each effort-bearing cut item expands exactly one macro. A missing effort emits
an explicit comment and no TaskJuggler duration. Exact scheduled intervals use
their recorded start and end; an effort macro remains in the manifest but does
not compete with the fixed interval. `best_before` remains advisory, while a
deadline maps to `maxend` and `not_before` maps to a release milestone.

The serializer maps the core's deterministic importance order to TaskJuggler's
`priority` field only as a scheduler tie-breaker. This does not create a
Little Ant priority axis.

## Failure examples

The component rejects projections with another schema or with a missing
project, task list, manifest, manifest digest, manifest bytes, or warning list.
The host rejects claims from an unavailable EffortProfile revision before Lua
runs. Invalid UTC instants fail inside the isolated runner without publishing
an artifact. TaskJuggler syntax is validated in the standard-Pack contract
suite with `tj3 --check-syntax --no-reports`.

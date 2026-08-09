# Implementation handoff

Current slice and gate: **S09 — Sources, Packs, imports, and repair; implementation in progress.**
S00-S08 are executable and mostly stable; S08 closure items remain open below.
Coverage labels stay conservative until every required recovery, uncertainty, and paired-surface row is fully evidenced.


Last committed baseline: **a292e0f** (`feat(export): establish host-owned publication boundary`).
The current milestone establishes canonical structural Pack verification. This
file stays editable between milestone commits.

## Implementation now available

- append-only replayable JSONL command groups, typed sparse results, persisted
  integrity-protected InteractionEnvelopes, factual loading progress, and the
  dumb Vty REPL foundation;
- Feed-first Raw triage, Natures/Templates, RawShelves, ListEntries, typed Raw
  links, duplicate suspicion, child Work, Domains, sibling-only importance
  insertion, and exact identity/handle separation;
- decaying human judgment, continuous adaptive ordering, nearby skip,
  provisional placement, provocative validation, contradiction recovery,
  independent Impact/Effort evidence, and optional phase;
- hierarchical replay-safe weighted forecast, Domain continuity/scope,
  N-step Dependency forwarding, Focus/WIP, skip diagnosis, Pomodoro, break,
  archive/restore, and checklist runs;
- exact dates/notices, repeatable jitter, recurrence, habit outcomes,
  scheduled commitments, operational-day boundaries, and truthful standing
  outcomes;
- ExternalEntity and ContactPoint state, Wait gates/reviews, Nature-aware
  Delegation coverage, immutable external effects, profiles/configuration,
  age-v1 encrypted vaults, and a profile-scoped AF_UNIX vault agent;
- dumb mini-simulations for external-condition Wait activation and manual
  Delegation from skip diagnosis through observed handoff;
- effect edit, defer, reject, approval, durable dispatch intent, and receipt
  transitions, with deferred effects excluded from the forecast.
- `lant doctor` runs before ordinary replay and auto-tick, reports the last
  valid cursor and event count, and identifies the first malformed event by
  canonical segment, physical JSONL line, and byte offset without mutating the
  dataset.
- a content-addressed repair plan can correct a provable segment-filename hash
  mismatch in a separate sibling dataset, replay the complete candidate, write
  a durable verification receipt, and reuse that candidate idempotently;
  unsupported corruption and stale plans fail before creating a candidate, and
  the live authority remains byte-for-byte unchanged.
- `lant repair` exposes separate preview, candidate-build, and cutover
  checkpoints with no default consent; cutover durably records its exact plan,
  uses an atomic same-filesystem directory exchange, resumes forward from
  pre- or post-exchange interruption, and retains the former authority as a
  read-only backup. Dry-run writes no repair artifact.
- `lant export` resolves a named, versioned exporter through an injected
  read-only port and supplies only a deterministic sparse structural
  projection. Export code receives no destination path or filesystem
  authority. The host either emits the artifact bytes to stdout or exclusively
  publishes one private new regular file through a same-directory temporary
  file and atomic no-clobber link; unsafe targets fail before exporter
  invocation, and dry-run writes nothing. The production registry remains
  empty until the Pack runtime is implemented: the standard serializers belong
  to the standard Pack rather than to the Haskell core.
- `little-ant/pack@1` has one closed concrete manifest shape with permissions
  owned by individual executable components. The canonical `.lantpack` writer
  emits one reproducible ZIP32/store encoding, and the structural verifier
  reconstructs the complete archive byte-for-byte before decoding strict JCS
  control documents or validating payload ownership, limits, lengths, and
  SHA-256 digests. It extracts nothing and produces a structural type that the
  executable registry cannot consume. Signature authentication and trust
  classification remain the next authority boundary.

## Last green gate

The most recent full commands were:

    nix develop -c make build test cli-test
    nix develop -c make python-test spec-audit vocabulary

Every Haskell test suite, all 16 conformance tests, the canonical-ID audit, the
public-vocabulary guard, and explicit formatting checks pass at this
checkpoint. The targeted S09 source suite has 22 passing
source/translation/diagnostic/repair tests, including both cutover crash phases
and the public no-default consent flow. The new S09 export suite has 7 passing
tests for deterministic projections, stdout, dry-run, exclusive publication,
pre-invocation target rejection, exporter failure, and registry compatibility.
The structural Pack suite has 8 passing tests for reproducible archives, JCS,
closed schemas, component permission isolation, path ownership, payload
integrity, canonical ZIP mutation rejection, and Unicode path safety. The full
build, every Haskell suite, the isolated CLI end-to-end test, formatting, and
targeted lint for the new Pack code pass. The CLI test now isolates all four
XDG roots, so a developer's real profile cannot contaminate it. The aggregate
`make ci` gate remains red only at the repository-wide HLint baseline; those
pre-existing hints are outside this milestone and S09 remains in progress.

## Remaining S08 closure (carried forward from prior checkpoint)

Before marking the slice verified, close these deliberately visible gaps:

- request-not-yet-made must create explicit enabling Work plus its declared
  successor response Wait rather than display educational text only;
- prerequisite, absolute-time, and Place branches from blocked/waiting need
  complete previews instead of falling through to generic recovery copy;
- Wait follow-up, blocker replacement, custom date/time, repeated-follow-up
  strategy, and source-observed resolution need their complete state paths;
- Delegation no-response must honor `once | every | none`, produce a separate
  approval-bearing follow-up when allowed, and use strategy review at the soft
  cap; completion/refusal need full Nature-aware reconciliation;
- proposed-message editing after creation, adapter delivery, effect recovery,
  duplicate-risk retry, and compensation need executable paths;
- add CLI-level tests for profile/config/vault and the missing `vault update`
  surface; tighten secret-memory zeroization limitations where the Haskell
  `Text` representation permits;
- run `make ci`, not only `make test`, before declaring the slice closed.

## Next work

Finish S09 from [`slices/09-sources-packs-and-adapters.md`](slices/09-sources-packs-and-adapters.md) before continuing to S10.
Next, authenticate the exact manifest bytes with Ed25519, classify built-in,
official, community, untrusted, and revoked signers, and implement the
content-addressed store, exact profile pins, and read-only component registry.
Then implement the fresh-process HsLua runner and ship the standard Lua tree,
table, RFC 4180 CSV, Org, self-contained HTML, and TaskJuggler exporters through
that boundary. Continue afterward with the Raw-first import/adapters. The
`Corrupt history/repair` row is implemented; formal evidence registration and
the complete S09 gate still precede `verified`.

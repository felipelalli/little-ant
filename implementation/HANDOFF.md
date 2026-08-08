# Implementation handoff

Current slice and gate: **S08 — Waits, Delegation, effects, profiles, and
credentials; implementation in progress.** S00-S07 have executable vertical
coverage and the complete test suite remains green. Coverage labels are still
conservative until the owning scenario rows include every specified recovery
and assisted pair.

Last verified commit: none; changes remain uncommitted under the repository
commit policy.

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

## Last green gate

The most recent full command was:

    nix develop -c make test

All 16 S08 tests and every earlier test suite passed. The S08 tests now include
live vault-agent behavior and public guided Wait/Delegation simulations.

## Remaining S08 closure

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

Finish S08 from [`slices/08-waits-delegation-and-effects.md`](slices/08-waits-delegation-and-effects.md).
Do not advance coverage rows merely because the happy path exists. Then move
to S09 in this order: SourceBinding/observations and translation; Pack
verification/runner; standard import/export surfaces; Calendar/effects; command
registry and repair.

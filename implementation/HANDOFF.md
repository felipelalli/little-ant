# Implementation handoff

Current slice and gate: **S09 — Sources, Packs, imports, and repair; implementation in progress.**
S00-S08 are executable and mostly stable; S08 closure items remain open below.
Coverage labels stay conservative until every required recovery, uncertainty, and paired-surface row is fully evidenced.


Last verified baseline commit: **3b4e975** (`fix(cli): restore a green command surface`).
The current milestone adds the read-only half of corrupt-history recovery; this
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

## Last green gate

The most recent full commands were:

    nix develop -c make test
    nix develop -c make python-test spec-audit vocabulary

Every Haskell test suite, all 16 conformance tests, the canonical-ID audit, and
the public-vocabulary guard passed. S09 now has 14 passing source/translation/
diagnostic tests.

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
Current focus in this slice is: candidate-based `lant repair`, followed by safe
export hosting, Pack protocols, and Raw-first import/adapter paths. The combined
`Corrupt history/repair` coverage row remains `planned` until repair constructs,
fully replays, and previews a separate replacement dataset.

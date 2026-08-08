# S08 — Waits, delegation, effects, profiles, and credentials

Status: **planned**

## Outcome

Implement external responsibility without fabricated truth: Wait review,
ExternalEntity contacts, Delegation, immutable effect approval and receipts,
typed profiles/configuration, and the encrypted local vault.

## Canonical flow rows owned

- Wait activation and review
- Delegation lifecycle
- Profiles, preferences, and credential vault

Generate all owning-row references plus MOD-007, MOD-030, MOD-050..051,
MOD-064, MOD-090..092, WRK-028..034, WRK-050..061,
WRK-119..121, WRK-134..138, DAT-024..027, DAT-057..073,
FOC-034..036, UX-W00..W03, UX-A01..A02, UX-D01..D04,
UX-CNT00..CNT01, UX-VLT00, UX-CFG00, UX-EFX00.

## Work

1. Implement Wait as a gating condition with explicit activation,
   `review_not_before`, typed review outcomes, pressure, history, strategy
   change, source-confirmed proposal, and no implicit follow-up Work.
2. Implement ExternalEntity and owner-addressed contact/delivery bindings with
   typed `@` handles and no Party alias.
3. Implement proposed/active/terminal Delegation, Nature-aware coverage,
   mandatory `once | every | explicitly none` follow-up policy, observed
   handoff activation, soft follow-up cap, and outcome reconciliation.
4. Implement the immutable effect revision, exact approval, durable
   dispatch-before-IO, receipt, retry, unknown outcome, and explicit
   compensation protocols.
5. Implement non-merging named profiles, typed XDG paths/YAML schemas,
   preferences/calibration/integration separation, and redacted inspection.
6. Integrate a reviewed age-v1 implementation for whole-file atomic vaults,
   profile-scoped memory agent, bindings, lock/unlock, rotation, backup,
   recovery, and no-echo terminal input.

## Gate

- a proposed Delegation never suppresses human execution;
- an active Wait and a Dependency never borrow each other's semantics;
- no provider is called before an immutable approved effect revision is
  durably recorded;
- unknown provider outcome cannot be retried without the canonical duplicate-
  risk branch;
- secrets never enter JSONL, projections, logs, checkpoints, model context,
  argv, environment, test goldens, or Pack input;
- vault cryptographic vectors, permissions, atomic replacement, crash points,
  and redaction threat fixtures pass.

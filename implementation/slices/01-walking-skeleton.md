# S01 — Walking skeleton: start, Feed, persist, replay

Status: **complete and verified**

## Outcome

Prove the end-to-end architecture with the smallest canonical behavior:
pristine start, text Feed into one Inbox Raw, durable restart/replay, sparse
inspection, and a pending next interaction bound to the accepted dataset.

## Canonical flow rows owned

- Shared frame and footer
- JSONL loading splash
- Palette/command escape
- Revision/stale response
- Reference selection
- Restore/startup to `next`
- Pristine first start
- Feed text input

Generate every reference listed by those rows in
[`flow-coverage.md`](../../spec/little-ant-1.0/ux/flow-coverage.md). Also load
PRD-001..014, MOD-001, MOD-008..010, MOD-023, MOD-054, FED-001..009,
DAT-001..010, DAT-044, DAT-051..056, UX-001..024, UX-029..032,
UX-040..049, UX-075..076, UX-094, and UX-191..204.

## Work

1. Implement the immutable JSONL command-group segment store, writer lock,
   hash/sequence validation, replay fold, canonical cursor, blob boundary, and
   factual loading callback from [`architecture.md`](../architecture.md).
2. Freeze the v1 event/result registry mechanics with the minimum Feed, Raw,
   interaction, and compensation cases. Add pure upcast and unknown-version
   failure seams before later event kinds exist.
3. Implement UUIDv7 identity, mnemonic Raw handles, canonical technical
   references, dataset revision, command ID, actor attribution, and sparse
   result presence rules.
4. Implement the canonical command dispatcher, `lant` option parsing,
   `--profile`, `--dry-run`, supported schema negotiation, typed errors, and
   exact-reference resolution.
5. Implement pristine `next`, UX-E00, Feed input, Feed confirmation/result,
   `/show +raw`, contextual palette, and exact pending-envelope recovery.
6. Implement the terminal harness only as a consumer of envelopes. Include
   startup splash, capability-safe frame/footer, immediate keys, input mode,
   Escape, and clean shutdown.
7. Implement Feed undo as command-group compensation and stale-response
   replacement without adding general later-slice maintenance.
8. Freeze the first byte-identical accepted-dataset corpus and replay both
   current and upcasted event versions from zero.
9. Add a minimal headless protocol client that consumes the same envelopes and
   action IDs as the REPL. It exists to prove the surface boundary early, not
   to introduce a second grammar or public UI.
10. Make writer-lock waiting bounded and interruptible, with deterministic
    contention fixtures. Add replay-budget fixtures at startup; if the budget
    is exceeded, only a disposable projection checkpoint may be introduced —
    never a snapshot event or a shortcut around full-replay equivalence.

## Acceptance path

```text
clean profile → lant → pristine screen → /feed → text → accept
→ Raw result → process exit → lant → factual replay → same Raw identity
→ /show +handle → sparse canonical projection
```

Required adversarial fixtures include empty input, cancel before acceptance,
dry-run, stale Feed confirmation, concurrent writer, lock timeout/interruption,
torn temporary segment, unknown event major, malformed accepted segment,
redirected output, `TERM=dumb`, and Feed undo before/after a dependent mutation.

## Gate

- incremental fold and replay-from-zero agree byte-for-byte on canonical
  projection and cursor;
- no Feed metadata form appears before Raw persistence;
- rendering or restart consumes no semantic randomness;
- no partial command group becomes canonical across every injected crash point;
- a malformed canonical segment stops writable startup without silent repair;
- lock contention returns a typed retry-safe result and appends nothing;
- the headless client and REPL expose identical envelope/action identities for
  the owned paths;
- the owned dumb evidence passes; paired assisted clauses remain explicitly
  partial until S11.

## Not in this slice

Raw disposition, Nature, Brick creation, importance, general forecast,
external source reconciliation, live provider IO, or a complete public command
catalog.

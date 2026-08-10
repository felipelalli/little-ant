# Little Ant 1.0 alpha contract

Status: **implemented and validated for local daily use**

The alpha exists to put the dumb REPL and migrated real v0 data into daily use
as early as possible. It is a local, single-user release rather than a claim
that every 1.0 integration and assisted surface is finished.

## Supported alpha surface

The alpha gate covers:

- immediate Feed into durable Raw and lazy triage into Work, lists, shelves,
  hierarchy, and Domains;
- sibling importance ordering, deterministic weighted `next`, blocker
  forwarding, Focus, pause, done, skip diagnosis, decomposition, archive, and
  restore;
- search, show, history, undo, redo, dataset replay, `doctor`, typed errors,
  and global dry-run;
- guided title and attached-description revision;
- safe migration of the user's observed signed-v0.1 event vocabulary into an
  empty selected v1 profile; and
- local Nix installation as `lant 1.0.0-alpha.1`.

Commands outside this list remain visible because their implementation is
useful for testing, but their help and documentation mark them experimental.
An experimental command is not an alpha compatibility promise.

## Migration boundary

The default legacy source is
`~/.local/share/little-ant/events.jsonl`; an explicit path may override it.
Preflight is harmless by default. Candidate construction is isolated, cutover
requires separate human consent, and the source remains byte-for-byte
untouched.

The local alpha uses three deliberately small commands against the selected
empty profile:

```sh
lant migrate
lant migrate --build
lant migrate --cutover
```

`--from-v0 EVENTS.jsonl` overrides the default source in any stage. The bare
command performs strict inspection only. `--build` writes and fully replays a
content-addressed sibling candidate. A later, separately typed `--cutover`
invocation is the alpha's explicit consent: it atomically exchanges the live
dataset with that exact candidate and retains the former empty target as a
named backup. Global `--dry-run` never creates a candidate or performs the
exchange.

Migration uses a recovery-only startup path. It resolves and validates the
selected profile and its canonical dataset location, but does not parse or
initialize preferences, calibration, integrations, Packs, vaults, providers,
or network transports. A stale optional subsystem therefore cannot block v0
inspection, candidate construction, or cutover. Ordinary commands continue to
validate the complete profile.

The candidate contains the exact source bytes, a machine-readable identity
map, a build receipt, and canonical v1 events. A durable adjacent journal makes
an interruption immediately after atomic exchange resumable. A failed build
may be quarantined beside the target and rebuilt; neither it nor inspection
changes the live profile. The original v0 file is never renamed, rewritten,
or deleted.

The alpha accepts exactly the event types observed in the user's current log:

```text
brick_captured         brick_enriched        brick_described
seed_promoted          brick_ready           brick_regressed
brick_started          brick_stopped         brick_completed
brick_killed           brick_superseded      dependency_added
comparison_recorded    wait_recorded         party_registered
requester_attributed   source_attached       source_checked
fed                    seeds_extracted       skip_taken
order_sanity_proposed  flow_opened           focus_served
wip_flagged
```

All source lines must still satisfy the signed `v0.1.0` schema and shipped
upcasts. The v0 administrative migrator preserved intrinsic IDs while renaming
`raw_captured` to `fed`, `energy` to `weight`, and `session` to `flow`; strict
preflight recognizes only those recorded canonical lineages in addition to
the current v0.1 wire shapes. A new event type or version stops before mutation
and points to the beta migration work; it is never skipped. The original
archive and historical fields remain inspectable even when they do not become
current v1 semantics.

The selected v1 target must be empty. Merging into existing v1 data and
interactive repair of ambiguous legacy structure are beta capabilities.

## Alpha promotion gate

The alpha is ready for daily use only when:

1. a sanitized fixture covers all 25 accepted legacy event types;
2. preflight against a private copy of the real source reports no unsupported
   or blocking issue without committing personal data to Git;
3. failed preflight/build and dry-run leave source and live target unchanged;
   cutover interruption either leaves the old target in place or a fully
   replayed candidate live, and a retry deterministically finishes the retained
   backup;
4. the candidate replays from zero with its recorded projection and identity
   hashes;
5. a migrated Brick can be searched, ordered, selected, focused, skipped,
   decomposed, completed, and recovered after restart; and
6. the full existing test suite plus the alpha end-to-end simulation passes.

All six conditions were satisfied on 2026-08-10. The private v0 preflight and
candidate build were exercised only in isolated temporary XDG roots; no
personal titles or event payloads entered the repository. The installed
artifact reports `lant 1.0.0-alpha.1`.

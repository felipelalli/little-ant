# 20. Existing Little Ant Brick review

No Little Ant data was mutated during this design session. In particular, no
1.0 root Brick was created and no existing Brick was completed, dropped, or
superseded.

The agreed future process is:

1. finish the conceptual questions;
2. create a root/project Brick named `Little Ant 1.0`;
3. review every existing Little Ant-related Brick with the user;
4. ask which useful idea should be absorbed into the 1.0 design;
5. attach or recreate the accepted work under the 1.0 root;
6. only then mark the old Brick done, dropped, or superseded as appropriate;
7. produce the implementation and v0-to-1.0 migration plan.

## 20.1 Preliminary mapping, not final disposition

The following mapping preserves the initial repository/backlog inspection. It
is a hypothesis for the later question session, not authorization to mutate
the data.

Likely already absorbed by the 1.0 design:

| Brick | Preliminary interpretation |
|---|---|
| `4de709d` dates | Absorbed by `not_before`, `best_before`, and `deadline`. |
| `d9c18f8` impact | Impact is absorbed; old generic weight is removed. |
| `f2a62b8` placement | Absorbed by from-birth hierarchical placement. |
| `a232a74` break positions | Absorbed by local child ordering after break. |
| `5d41ad7` parent review | Absorbed by `review_parent`. |
| `82e789d` interrupted rounds | Likely absorbed by resumable probe design; persistence details remain open. |
| `eabdce0` compare reason | Likely absorbed by evidence provenance and optional reason. |
| `be7f87c` forecast | Absorbed and expanded into the forecast projection. |
| `c16963b` done direct | Brick-side intent is absorbed by direct terminal status. |
| `dc01980` done any stage/raw | Brick-side intent is absorbed; Raw now uses review/archive instead of done. |
| `bf4265f` REPL | The REPL is now required for 1.0 as a deterministic guided harness; exact interaction details remain open. |

Likely obsolete or substantially superseded:

| Brick | Preliminary interpretation |
|---|---|
| `d1ad5f8` promote to commit rename | Both lifecycle operations disappear. |
| `2467144` stage unification/supersede seed | Old stages disappear; any useful supersede semantics need extraction. |
| `6db8938` grooming meta-Brick | Maintenance moves to derived proposals. |
| `dbf72a7` subset sort | Must be reconsidered under sibling-scoped hierarchical order. |

Still visibly open:

| Brick | Preliminary interpretation |
|---|---|
| `f7048ad` snooze | Needs separation from cooldown, wait, and `not_before`. |
| `2ca8d39` flow stop/pause/lighter/change subject | Flow and focus grammar remains open; old weight-based “lighter” is obsolete. |
| `355a9b7` status line | Projection may remain useful; exact 1.0 surface is open. |

## 20.2 Remaining inventory captured for later review

The following IDs and shorthand titles were observed and must be reviewed
individually. Shorthand titles are only navigation aids; the CLI remains the
authority for their full current data.

Committed at inspection time:

```text
09a47ce blobs
355a9b7 status line
6db8938 grooming
dc01980 done any stage
e62a98a consumable
```

Seeds at inspection time:

```text
829fbae artifacts: description/source/attachment
6b5261e Party null bug
75456d6 ready/wait bug
a232a74 break positions
b8b92b6 dropped blocker bug
d9c18f8 impact
4de709d dates
c16963b already done
c524be5 mutators echo updated Brick
2467144 unify/supersede seed
d1acce4 Party references/about
0741514 concurrent log
ff6fd63 mobile WASM
7b678e2 dependency remove
86e68cf mention grammar
d58e0e3 Party slug
1437d01 import TODOs
f2a62b8 placement
f4b333e Metro web
d1ad5f8 rename promote/commit
2ca8d39 flow
eabdce0 comparison reason
24ba73f title normalization
5d41ad7 parent done
ede9f19 recurrence/habits
ed8176f README rewrite
6b212ab skill review
5205704 sync round
82e789d interrupted rounds
18b7326 search/theme
f8e836d seven triggers
35bf548 archive
6a62628 metadata
dbf72a7 subset sort
be7f87c forecast
bf4265f REPL
f7048ad snooze
```

At the time of inspection there was no existing root named `Little Ant 1.0`.

# Open release decisions

Only unresolved semantic, protocol, migration, or security boundaries live
here. Tuning values belong in
[`configuration-and-calibration.md`](configuration-and-calibration.md);
ordinary implementation choices wait for the implementation plan.

An `OPEN-*` item is not permission to guess. It names the exact boundary and
the UX or threat-model evidence required to close it.

The 1.0 contract currently has **no open release-blocking semantic boundary**.
The v0.1 projection and cutover are closed by `MIG-001..044` and UX-MIG00..02.
New uncertainty found during the final contradiction audit must receive a new
ID rather than being hidden in prose.

## Blocking decisions

None.

## Deliberately not release blockers

These do not justify inventing more core behavior before simulation:

- exact forecast curve coefficients and cooldown lengths;
- exact screen region sizes, colors, terminal library, or web framework;
- whether a particular personal Template is popular;
- automatic semantic causality for skip patterns;
- arbitrary generic plugins or custom event hooks;
- cross-device draft synchronization;
- a global world-object catalog;
- alternative storage or selection engines;
- points, leaderboards, or punitive habit scoring.

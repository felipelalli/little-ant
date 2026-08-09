# ADR 0011: Own planning cuts and custody manifests in the core

## Status

Accepted for S09.

## Context

TaskJuggler needs estimates, dependencies, scheduling constraints, resources,
and a non-overlapping selection of work. Letting Lua infer those meanings would
make the plan depend on extension code. Recording an export as a new dataset
event would instead violate the read-only export boundary and require public
planning commands that the closed 1.0 command catalog deliberately rejects.

The final `.tjp` digest is also insufficient custody for later actuals: benign
editing or report customization changes the file while the source planning cut
can remain the same.

## Decision

The Haskell core deterministically builds `little-ant/taskjuggler@1` from the
explicit export scope and current human-reviewed state. An effort-bearing
finite ancestor closes that branch of the cut; otherwise finite leaves are
selected. Standing owners are excluded as unbounded while their finite
descendants remain eligible. Missing effort remains visible and receives no
default. Claims from an unavailable EffortProfile revision fail closed.

The core maps active dependency endpoints onto cut representatives, preserves
the deterministic structural/importance order for scheduler tie-breaking, and
owns temporal interpretation. It records exact source cursor and hash, scope,
roots, cut, the complete EffortProfile, warnings, factory resource/calendar
assumptions, projection version, and exact Pack/component identity in a
canonical RFC 8785 manifest.

An explicit CLI export confirms its requested scope and the deterministic cut
already implied by current effort claims. The interactive surface shows the
same cut in its export preview. Neither path appends an event. The `.tjp`
contains the complete manifest as numbered unpadded-base64url comment lines and
its SHA-256 digest. The host separately reports the final artifact digest.

The isolated Lua component only serializes this projection. A future actuals
SourceAdapter must reconstruct and verify the embedded manifest by its own
digest and fail closed when the custody block is absent or changed; it must not
use the mutable `.tjp` artifact digest as planning identity.

## Consequences

- Pack code cannot invent estimates, alter cut membership, or silently choose
  resources and calendars;
- parent and descendant effort cannot be double-counted in one planning run;
- WIP exports total effort with a warning until conservative remaining-effort
  evidence exists;
- TaskJuggler's `priority` keyword remains a serializer detail rather than a
  restored Little Ant priority axis;
- exports remain replay-neutral and safe for stdout while later actuals retain
  a stable source identity;
- the factory UTC, Monday-Friday, six-hour resource assumption is explicit and
  replaceable only through a future versioned planning profile.

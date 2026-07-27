# 15. TaskJuggler planning boundary

## 15.1 Hours are a planning concern

Little Ant does not store hours as a Brick property.

- A Brick stores a discrete effort class and its EffortProfile version.
- The profile maps that class to one structural macro.
- The macro expands into optimistic, realistic, and pessimistic hours.
- Resources, calendars, and resource efficiency belong to planning inputs and
  the immutable planning manifest, not to intrinsic Brick effort.

TaskJuggler schedules supplied planning inputs. It does not infer effort from
Little Ant semantics.

## 15.2 One macro per planned item

Every planning-cut item that receives effort selects exactly one structural
macro. That macro supplies all three scenarios; neither the planning
projection nor a target-format exporter may select a different source estimate
independently for each scenario.

The initial profile mapping is defined in
[Effort and calibration](10-effort-rating-and-calibration.md). Aliases used by
older personal planning files are not part of the Little Ant core vocabulary.

For work that has not started, export its total effort class. For WIP:

- use a derived remaining-effort class when conservative progress evidence
  supports it;
- otherwise export the provisional total class and emit an explicit warning;
- never infer progress merely from elapsed focus time.

Low confidence does not block planning. The manifest records the best-supported
class and an explicit warning.

## 15.3 Planning cut

An export begins from roots selected for that planning run. The core proposes
a non-overlapping **planning cut** through those scopes:

- each selected cut node represents all work below that point for this plan;
- no selected node may have a selected ancestor or descendant;
- confirmed-complete decompositions allow the cut to descend safely;
- open or uncertain decomposition coverage is exposed as a gap or warning;
- the human confirms the proposed cut or coarsens it.

Each confirmed cut node becomes an effort-bearing TaskJuggler leaf task.
Structural parent tasks may also appear in the generated project, but they
carry no effort when descendant cut nodes already represent that scope.
Therefore effort is never counted at both a parent and its descendant.

A Little Ant Brick can be a container with children while representing a
TaskJuggler leaf in one particular planning cut. “Leaf” is a property of the
exported plan, not a restriction on the Little Ant domain model.

## 15.4 Immutable planning manifest

Each confirmed simulation saves an immutable planning manifest outside the
core's operational domain state. It is an artifact, not a Brick and not a
mutable `PlanningScenario` entity.

At minimum the manifest records:

- the event-log cursor and integrity hash;
- selected export roots;
- the confirmed non-overlapping cut;
- EffortProfile ID and version;
- selected macro and warnings for each cut item;
- resources, calendars, efficiency, and scenario inputs;
- the canonical versioned planning projection used for export;
- exporter Pack ID, component ID, version, content hash, and contract version;
- other data required for reproducibility.

The generated `.tjp` must be reproducible by applying the exact pinned
exporter to the projection retained by the manifest. Creating or inspecting
the manifest never causes an exporter to run during event replay. The exact
manifest schema, storage location, and retention policy remain open.

## 15.5 Importing actuals

Generated TaskJuggler tasks embed their Little Ant Brick IDs. On import:

1. the TaskJuggler SourceAdapter resolves actuals by embedded ID;
2. it prepares a grouped preview of the proposed evidence;
3. the human confirms the batch or excludes individual rows;
4. confirmed actuals are appended as observations without rewriting estimates.

Legacy or ambiguous TaskJuggler tasks require explicit human mapping. The
SourceAdapter must never heuristically mutate a Brick when identity is
uncertain.

The estimate, its EffortProfile version, and the observed actual remain
separate so calibration and scope mismatches can be investigated.

## 15.6 Standard-Pack exporter

The standard Pack distributed with Little Ant 1.0 contains a TaskJuggler
`ReadOnlyExporter` implemented in Lua. The core produces and validates the
planning projection; the exporter owns only TaskJuggler-specific `.tjp`
serialization and returns bytes, media type, a suggested filename, and
warnings.

The exporter has no direct filesystem, network, subprocess, or canonical
mutation authority. The invoking surface writes the result. Running `tj3` or
publishing a plan is a separate external action. TaskJuggler actuals use a
separate SourceAdapter rather than broadening the exporter.

The exporter is also the reference executable Pack component: its source,
manifest, fixtures, conformance tests, and failure examples ship with 1.0 and
exercise the same public runner and contract available to community authors.
See
[Lua Pack runtime, credentials, exporters, and UI adapters](34-lua-pack-runtime-credentials-exporters-and-ui-adapters.md).

## 15.7 Still open

- How dependencies outside the selected export scopes are represented.
- The exact manifest schema, location, retention, and naming.
- How resources, calendars, and efficiency are selected for a run.
- Thresholds for warning about estimate-versus-actual discrepancies.
- How a profile revision affects a new plan containing old estimates.
- The final generic export command grammar and versioned planning-projection
  schema.

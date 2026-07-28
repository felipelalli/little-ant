# Little Ant 1.0 contract tests

This directory is the spec-first executable contract for Little Ant 1.0. It
contains no application implementation.

## Layers

1. `generated/*.plan.json` contains every obligation emitted by
   `allium plan`.
2. `generated/*.model.json` contains the generator-aware domain model emitted
   by `allium model`.
3. `scenarios/*.json` contains hand-shaped end-to-end flows and deterministic
   mini-simulations based on real use cases.
4. `Spec.hs` verifies generated-artifact integrity and runs every plan and
   scenario through the implementation bridge.

The generated plans currently contain **1,446 obligations** across the
composed root and eight modules. The 16 end-to-end scenarios add 120
assertions. A plan response is accepted only when it returns exactly one
result for every obligation ID—no missing, duplicate, or invented result.

## Regenerate

Run this after any `.allium` change:

```sh
bash test-v1/generate-allium-artifacts.sh
```

The script requires `allium` and `jq`. Generated JSON is checked in so spec
review and test review can happen in the same diff.

## Implementation bridge

The test suite remains independent of the implementation's internal Haskell
module layout. The repository ships the `lant-v1-test-driver` executable,
which accepts exactly one JSON request on stdin and returns exactly one JSON
response on stdout. Cabal's contract launcher discovers the freshly built
driver automatically:

```sh
cabal build exe:lant-v1-test-driver
cabal test little-ant-v1-contract-test
```

An explicit external driver can still be selected when testing another build:

```sh
LANT_V1_TEST_DRIVER=/path/to/lant-v1-test-driver \
  cabal test little-ant-v1-contract-test
```

The driver path is an executable path or a command discoverable on `PATH`; it
does not accept command-line arguments. All request data travels through
stdin.

### Plan request

```json
{
  "protocol_version": 1,
  "request_kind": "allium_plan",
  "module": "judgment",
  "plan": {"version": 3, "obligations": []},
  "model": {"version": 3}
}
```

### Scenario request

```json
{
  "protocol_version": 1,
  "request_kind": "scenario",
  "scenario": {
    "id": "priority-uncertainty",
    "steps": [],
    "assertions": []
  }
}
```

### Driver response

```json
{
  "protocol_version": 1,
  "ok": true,
  "results": [
    {
      "id": "rule-success.SomeRule",
      "passed": true,
      "detail": null
    }
  ],
  "diagnostics": []
}
```

For an Allium plan request, `results` must match the plan's obligation IDs
exactly. For a scenario request, they must match the scenario's assertion IDs
exactly. `ok` cannot hide a failed assertion.

## Scenario protocol

A scenario is a declarative black-box test contract, not production CLI
syntax. The driver executes `steps` in order against one isolated state:

- `operation` names either an Allium trigger or contract call, or an explicit
  test-fixture operation such as `CreateFixture`;
- `bind` assigns the complete result to a symbolic name;
- `bind_result` assigns named fields from the result;
- strings beginning with `$` resolve a previously bound value;
- `clock`, `random_evidence`, and `parameter_overrides` replace ambient time,
  randomness, and calibration policy for the whole scenario.

An assertion with `after` observes state immediately after that step;
`at: "after:<step-id>"` anchors an assertion operation to the same kind of
checkpoint. Without either field, it uses the final scenario state. An
assertion-local `fixture` instead creates the isolated state named there. The
assertion then runs a read-only `query` or a named observation `operation`,
optionally selects a `path`, and compares the result with `value` or
`value_from`. Operators use their literal meanings: scalar and set equality,
ordering, inclusive ranges, containment, counts, uniqueness, omission,
rejection, transition result, and absolute-tolerance checks. The driver must
reject unknown operations, references, paths, or operators; it must never
report them as passed.

Each scenario starts from an empty isolated domain except for state created by
its fixture steps. Drivers must not share event history, clocks, random
evidence, caches, or Pack state across scenarios.

## Full conformance and release gate

The implementation currently satisfies all 1,446 generated obligations and
120 scenario assertions. Run the observable progress path and the complete
release gate with:

```sh
python3 tools/v1-progress.py              # TOTAL 1566/1566
bash tools/probe-mutation-check.sh --verify-audit tools/probe-audit.md
bash tools/story-gate.sh
```

The mutation checker samples 30 unique obligations across all nine modules.
For each target it first requires green, changes the corresponding production
behavior or outside-world boundary, reruns `tools/v1-progress.py`, requires
that exact target to turn red, and restores and rebuilds pristine sources.
`tools/probe-audit.md` records every green-to-red outcome and any stayed-green
fake; the story gate fails closed for a missing, stale, or malformed audit.

The atomic-cutover scenario reads
`fixtures/v0-v1-atomic-cutover.jsonl`, a wholly synthetic mixed-history v0
archive. Its exact byte count, event count, SHA-256, and opaque identity maps
keep the reader and migration projection observable without exposing personal
v0 data.

## Mini-simulations

Simulation scenarios pin their clock, random seed, parameter overrides, sample
size, and tolerances. They test safety invariants as hard assertions while
recording calibration metrics separately. This allows daily use to refine
forecast weights, cooldowns, confidence decay, and review thresholds without
silently redefining priority or lifecycle semantics.

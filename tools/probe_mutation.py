#!/usr/bin/env python3
"""Behavior mutation runner for the Little Ant 1.0 conformance probes."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
from typing import Iterable

ROOT = Path(__file__).resolve().parent.parent
REQUIRED_MODULES = {
    "root",
    "domain",
    "material",
    "judgment",
    "execution",
    "selection",
    "interaction",
    "integration",
    "migration-v0-v1",
}
RULE_PREFIXES = ("rule-entity-creation.", "rule-failure.")


class AuditError(RuntimeError):
    """A malformed manifest, response, mutation, or audit result."""


@dataclass(frozen=True)
class Mutation:
    path: str
    before: str
    after: str


@dataclass(frozen=True)
class Sample:
    module: str
    obligation: str
    mutation: str
    boundary: bool
    behavior: str


MUTATIONS: dict[str, Mutation] = {
    "kernel-opaque-identity": Mutation(
        "src/LittleAnt/V1/Kernel.hs",
        'digestText (namespace <> ":" <> Text.pack (show ordinal))',
        "digestText namespace <> Text.take 0 (Text.pack (show ordinal))",
    ),
    "domain-party-label": Mutation(
        "src/LittleAnt/V1/Domain.hs",
        ", partyLabel = label\n        , partyType = partyKind",
        ', partyLabel = label <> " [mutated]"\n        , partyType = partyKind',
    ),
    "material-inline-review-state": Mutation(
        "src/LittleAnt/V1/Material.hs",
        "raw = Raw identifier Nothing (Just original) canonical authority\n"
        "        RawPending RawActive createdAt",
        "raw = Raw identifier Nothing (Just original) canonical authority\n"
        "        RawReviewedState RawActive createdAt",
    ),
    "priority-first-root-title": Mutation(
        "src/LittleAnt/V1/Priority.hs",
        "createPriorityRoot title randomEvidence now =\n"
        "  createPriorityBrick Nothing title randomEvidence now",
        "createPriorityRoot _title randomEvidence now =\n"
        '  createPriorityBrick Nothing "" randomEvidence now',
    ),
    "domain-focused-work-state": Mutation(
        "src/LittleAnt/V1/Domain.hs",
        "then brick\n            { brickWorkState = Wip\n"
        "            , brickRevision = bumpRevision (brickRevision brick)",
        "then brick\n            { brickWorkState = Idle\n"
        "            , brickRevision = bumpRevision (brickRevision brick)",
    ),
    "selection-deferred-candidate": Mutation(
        "src/LittleAnt/V1/Selection.hs",
        "| Priority.priorityInsertionStatus insertion "
        "/= Priority.InsertionDeferred = []",
        "| Priority.priorityInsertionStatus insertion "
        "== Priority.InsertionDeferred = []",
    ),
    "interaction-open-status": Mutation(
        "src/LittleAnt/V1/Interaction.hs",
        "interactionSessionStatus = InteractionOpen\n"
        "        , interactionSessionDomainRevision = domainRevision",
        "interactionSessionStatus = InteractionStale\n"
        "        , interactionSessionDomainRevision = domainRevision",
    ),
    "powered-up-validation": Mutation(
        "src/LittleAnt/V1/Interaction.hs",
        'unless (transport == "stdin") (Left PoweredUpTransportMustBeStdin)\n'
        "      parsePoweredUpProbe response",
        'unless (transport == "stdin") (Left PoweredUpTransportMustBeStdin)\n'
        "      parsePoweredUpProbe response >> Left PoweredUpOutputUnsupported",
    ),
    "process-sandbox-source-limit": Mutation(
        "src/LittleAnt/V1/Integration.hs",
        "sandboxLimitSourceBytes = 65536",
        "sandboxLimitSourceBytes = 1",
    ),
    "source-sync-receipt": Mutation(
        "src/LittleAnt/V1/SourceImport.hs",
        "{ importRunStatus = ImportCompleted\n"
        "        , importRunFinishedAt = Just now\n"
        "        , importRunReceiptHash = Just receipt",
        "{ importRunStatus = ImportCompleted\n"
        "        , importRunFinishedAt = Just now\n"
        "        , importRunReceiptHash = Nothing",
    ),
    "taskjuggler-manifest-revision": Mutation(
        "src/LittleAnt/V1/Planning.hs",
        ", planningManifestDatasetRevision = datasetRevision",
        ", planningManifestDatasetRevision = datasetRevision + 1",
    ),
    "taskjuggler-runtime-media": Mutation(
        "src/LittleAnt/V1/Planning.hs",
        ', "  media_type=\'text/x-taskjuggler\',"',
        ', "  media_type=\'application/octet-stream\',"',
    ),
    "web-ui-bind-host": Mutation(
        "src/LittleAnt/V1/Planning.hs",
        'session = WebUiSession identifier component "127.0.0.1" port',
        'session = WebUiSession identifier component "0.0.0.0" port',
    ),
    "web-ui-runtime-read-only": Mutation(
        "src/LittleAnt/V1/Planning.hs",
        ', "  return {channel=\'web\', read_only=true, envelope=input.envelope}"',
        ', "  return {channel=\'web\', read_only=false, envelope=input.envelope}"',
    ),
    "migration-seed-status": Mutation(
        "src/LittleAnt/V1/Migration.hs",
        'V0.Seed -> "active"',
        'V0.Seed -> "done"',
    ),
}


def parse_manifest(path: Path) -> list[Sample]:
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as error:
        raise AuditError(f"cannot read mutation manifest: {error}") from error
    if not lines or lines[0] != "module\tobligation\tmutation\tboundary\tbehavior":
        raise AuditError("mutation manifest has a missing or malformed header")
    samples: list[Sample] = []
    for line_number, line in enumerate(lines[1:], start=2):
        if not line or line.startswith("#"):
            continue
        fields = line.split("\t")
        if len(fields) != 5:
            raise AuditError(f"manifest line {line_number} must have five tab-separated fields")
        module, obligation, mutation, boundary_text, behavior = fields
        if boundary_text not in {"yes", "no"}:
            raise AuditError(f"manifest line {line_number} has invalid boundary marker")
        if mutation not in MUTATIONS:
            raise AuditError(f"manifest line {line_number} names unknown mutation {mutation!r}")
        if not behavior.strip():
            raise AuditError(f"manifest line {line_number} has no behavior description")
        samples.append(Sample(module, obligation, mutation, boundary_text == "yes", behavior))
    validate_manifest(samples)
    return samples


def validate_manifest(samples: list[Sample]) -> None:
    if len(samples) < 30:
        raise AuditError(f"mutation sample has {len(samples)} obligations; at least 30 are required")
    obligations = [sample.obligation for sample in samples]
    duplicates = sorted({item for item in obligations if obligations.count(item) > 1})
    if duplicates:
        raise AuditError("duplicate sampled obligations: " + ", ".join(duplicates))
    modules = {sample.module for sample in samples}
    if modules != REQUIRED_MODULES:
        raise AuditError(
            "sampled modules differ from the nine-module contract; "
            f"missing={sorted(REQUIRED_MODULES - modules)}; "
            f"unexpected={sorted(modules - REQUIRED_MODULES)}"
        )
    rule_weight = sum(sample.obligation.startswith(RULE_PREFIXES) for sample in samples)
    if rule_weight < 16:
        raise AuditError(f"only {rule_weight} sampled obligations are entity-creation/failure rules")
    boundary_weight = sum(sample.boundary for sample in samples)
    if boundary_weight < 10:
        raise AuditError(f"only {boundary_weight} sampled mutations cross outside-world boundaries")
    for sample in samples:
        plan_path = ROOT / "test-v1" / "generated" / f"{sample.module}.plan.json"
        try:
            plan = json.loads(plan_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            raise AuditError(f"cannot validate {sample.module} plan: {error}") from error
        matches = [item for item in plan.get("obligations", [])
                   if isinstance(item, dict) and item.get("id") == sample.obligation]
        if len(matches) != 1:
            raise AuditError(
                f"sample target {sample.module}:{sample.obligation} occurs {len(matches)} times"
            )
    for name, mutation in MUTATIONS.items():
        path = ROOT / mutation.path
        try:
            source = path.read_text(encoding="utf-8")
        except OSError as error:
            raise AuditError(f"cannot inspect mutation {name}: {error}") from error
        count = source.count(mutation.before)
        if count != 1:
            raise AuditError(
                f"mutation {name} behavior anchor occurs {count} times in {mutation.path}"
            )
        if mutation.after in source:
            raise AuditError(f"mutation {name} is already applied in {mutation.path}")


def evaluate_target_response(response: object, obligation: str) -> bool:
    """Return the exact target result, rejecting all malformed alternatives."""
    if not isinstance(response, dict):
        raise AuditError("driver response is not an object")
    if response.get("protocol_version") != 1 or not isinstance(response.get("ok"), bool):
        raise AuditError("driver response has malformed protocol metadata")
    results = response.get("results")
    if not isinstance(results, list):
        raise AuditError("driver response has no results array")
    observed: list[bool] = []
    for index, result in enumerate(results):
        if not isinstance(result, dict):
            raise AuditError(f"driver result {index} is not an object")
        identifier = result.get("id")
        passed = result.get("passed")
        if not isinstance(identifier, str) or not isinstance(passed, bool):
            raise AuditError(f"driver result {index} has malformed id/passed fields")
        if identifier != obligation:
            raise AuditError(f"driver returned unrelated result {identifier!r} for {obligation!r}")
        observed.append(passed)
    if len(observed) != 1:
        raise AuditError(f"target {obligation!r} occurs {len(observed)} times in the response")
    if response["ok"] != observed[0]:
        raise AuditError("driver ok flag disagrees with the exact target result")
    return observed[0]


def target_result(driver: Path, sample: Sample) -> bool:
    plan_path = ROOT / "test-v1" / "generated" / f"{sample.module}.plan.json"
    model_path = ROOT / "test-v1" / "generated" / f"{sample.module}.model.json"
    plan = json.loads(plan_path.read_text(encoding="utf-8"))
    model = json.loads(model_path.read_text(encoding="utf-8"))
    target = [item for item in plan["obligations"] if item["id"] == sample.obligation]
    request = {
        "protocol_version": 1,
        "request_kind": "allium_plan",
        "module": sample.module,
        "plan": {**plan, "obligations": target},
        "model": model,
    }
    try:
        process = subprocess.run(
            [str(driver)], cwd=ROOT, input=json.dumps(request, separators=(",", ":")),
            capture_output=True, text=True, timeout=120, check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        raise AuditError(f"cannot invoke driver for {sample.obligation}: {error}") from error
    if process.returncode != 0:
        detail = process.stderr.strip() or process.stdout.strip()
        raise AuditError(f"driver failed for {sample.obligation}: {detail}")
    try:
        response = json.loads(process.stdout)
    except json.JSONDecodeError as error:
        raise AuditError(f"driver returned malformed JSON for {sample.obligation}: {error}") from error
    return evaluate_target_response(response, sample.obligation)


class MutationGuard:
    """Apply exactly one source mutation and restore its original bytes."""

    def __init__(self, root: Path, mutation: Mutation):
        self.path = root / mutation.path
        self.mutation = mutation
        self.original: bytes | None = None

    def __enter__(self) -> "MutationGuard":
        self.original = self.path.read_bytes()
        text = self.original.decode("utf-8")
        count = text.count(self.mutation.before)
        if count != 1:
            raise AuditError(f"mutation anchor occurs {count} times in {self.mutation.path}")
        self.path.write_text(
            text.replace(self.mutation.before, self.mutation.after, 1), encoding="utf-8"
        )
        return self

    def restore(self) -> None:
        if self.original is not None:
            self.path.write_bytes(self.original)
            self.original = None

    def __exit__(self, _kind: object, _value: object, _traceback: object) -> None:
        self.restore()


def run_command(command: list[str], label: str, timeout: int = 600) -> str:
    try:
        process = subprocess.run(
            command, cwd=ROOT, capture_output=True, text=True, timeout=timeout, check=False
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        raise AuditError(f"{label} could not run: {error}") from error
    if process.returncode != 0:
        combined = (process.stdout + "\n" + process.stderr).strip().splitlines()
        detail = "\n".join(combined[-40:])
        raise AuditError(f"{label} failed:\n{detail}")
    return process.stdout


def build_driver(label: str) -> None:
    run_command(
        ["cabal", "build", "exe:lant-v1-test-driver", "exe:lant-pack-runner",
         "--ghc-options=-Werror"],
        label,
        timeout=900,
    )


def resolve_executable(component: str) -> Path:
    output = run_command(
        ["cabal", "list-bin", f"exe:{component}"],
        f"resolve {component}",
        timeout=120,
    )
    lines = [line.strip() for line in output.splitlines() if line.strip()]
    if len(lines) != 1:
        raise AuditError(f"cabal list-bin returned an ambiguous {component} path")
    executable = Path(lines[0])
    if not executable.is_file():
        raise AuditError(f"resolved executable does not exist: {executable}")
    return executable


def fingerprint_samples(samples: Iterable[Sample]) -> str:
    payload = [sample.__dict__ for sample in samples]
    return hashlib.sha256(
        json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    ).hexdigest()


def implementation_fingerprint() -> str:
    paths = {mutation.path for mutation in MUTATIONS.values()}
    paths.update({"tools/probe_mutation.py", "tools/probe-mutation-check.sh"})
    digest = hashlib.sha256()
    for relative in sorted(paths):
        digest.update(relative.encode("utf-8") + b"\0")
        digest.update((ROOT / relative).read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()


def render_audit(samples: list[Sample]) -> str:
    lines = [
        "# Little Ant 1.0 probe mutation audit",
        "",
        "This reproducible audit was produced by `bash tools/probe-mutation-check.sh`.",
        "Every row established the exact target as green, changed production behavior",
        "rather than its probe result, reran `tools/v1-progress.py`, and observed that",
        "same target turn red before restoring and rebuilding pristine sources.",
        "",
        f"- Manifest SHA-256: `{fingerprint_samples(samples)}`",
        f"- Implementation SHA-256: `{implementation_fingerprint()}`",
        f"- Sample size: **{len(samples)} unique obligations across nine modules**",
        "",
        "## Sampled green-to-red results",
        "",
        "| Obligation ID | Module | Behavior mutation | Boundary | Outcome |",
        "|---|---|---|---|---|",
    ]
    for sample in samples:
        behavior = sample.behavior.replace("|", "\\|")
        lines.append(
            f"| `{sample.obligation}` | `{sample.module}` | {behavior} | "
            f"{'outside world' if sample.boundary else 'domain'} | green → red |"
        )
    lines.extend([
        "",
        "## Stayed-green / fake results",
        "",
        "None.",
        "",
        "All sampled targets flipped red. No sampled fake required a behavior fix or",
        "an owner decision.",
        "",
    ])
    return "\n".join(lines)


def validate_audit(path: Path, samples: list[Sample]) -> None:
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as error:
        raise AuditError(f"mutation audit is missing or unreadable: {error}") from error
    manifest_line = f"- Manifest SHA-256: `{fingerprint_samples(samples)}`"
    implementation_line = f"- Implementation SHA-256: `{implementation_fingerprint()}`"
    if text.count(manifest_line) != 1:
        raise AuditError("mutation audit manifest fingerprint is missing or stale")
    if text.count(implementation_line) != 1:
        raise AuditError("mutation audit implementation fingerprint is missing or stale")
    if text.count("## Stayed-green / fake results") != 1:
        raise AuditError("mutation audit has no unique stayed-green/fake section")
    stayed_section = text.split("## Stayed-green / fake results", 1)[1]
    if not re.search(r"^None\.$", stayed_section, flags=re.MULTILINE):
        raise AuditError("mutation audit has an unacknowledged stayed-green/fake result")
    for sample in samples:
        row_pattern = re.compile(
            rf"^\| `{re.escape(sample.obligation)}` \| `{re.escape(sample.module)}` "
            rf"\| .* \| (?:outside world|domain) \| green → red \|$",
            flags=re.MULTILINE,
        )
        matches = row_pattern.findall(text)
        if len(matches) != 1:
            raise AuditError(
                f"mutation audit outcome for {sample.module}:{sample.obligation} "
                f"occurs {len(matches)} times"
            )


def git_snapshot() -> tuple[bytes, bytes]:
    status = subprocess.run(
        ["git", "status", "--porcelain=v1", "-z", "--untracked-files=all"],
        cwd=ROOT, capture_output=True, check=True,
    ).stdout
    diff = subprocess.run(
        ["git", "diff", "--binary", "--no-ext-diff"],
        cwd=ROOT, capture_output=True, check=True,
    ).stdout
    return status, diff


def run_audit(samples: list[Sample], write_audit: Path | None,
              verify_audit_path: Path | None) -> None:
    def interrupt(signum: int, _frame: object) -> None:
        raise AuditError(f"interrupted by signal {signum}")

    for signum in (signal.SIGHUP, signal.SIGINT, signal.SIGTERM):
        signal.signal(signum, interrupt)
    if verify_audit_path is not None:
        validate_audit(verify_audit_path, samples)
    original_git = git_snapshot()
    original_sources = {
        relative: (ROOT / relative).read_bytes()
        for relative in {mutation.path for mutation in MUTATIONS.values()}
    }
    grouped: dict[str, list[tuple[int, Sample]]] = {}
    for index, sample in enumerate(samples, start=1):
        grouped.setdefault(sample.mutation, []).append((index, sample))
    print(
        f"Validated {len(samples)} unique mutation samples across nine modules "
        f"and {len(grouped)} isolated behavior changes.",
        flush=True,
    )
    build_driver("initial pristine driver build")
    driver = resolve_executable("lant-v1-test-driver")
    os.environ["LANT_PACK_RUNNER"] = str(resolve_executable("lant-pack-runner"))
    active_guard: MutationGuard | None = None
    try:
        # Establish every exact target against the same pristine executable.
        for index, sample in enumerate(samples, start=1):
            if target_result(driver, sample) is not True:
                raise AuditError(
                    f"[{index}/{len(samples)}] pristine target is not green: "
                    f"{sample.module}:{sample.obligation}"
                )
        print("All 30 exact targets are green in the pristine driver.", flush=True)

        for mutation_index, (mutation_name, targets) in enumerate(
                grouped.items(), start=1):
            modules = {sample.module for _, sample in targets}
            if len(modules) != 1:
                raise AuditError(
                    f"isolated mutation {mutation_name} spans modules {sorted(modules)}"
                )
            module = next(iter(modules))
            active_guard = MutationGuard(ROOT, MUTATIONS[mutation_name])
            active_guard.__enter__()
            try:
                build_driver(f"mutated build for {mutation_name}")
                progress = run_command(
                    [sys.executable, "tools/v1-progress.py", "--module", module],
                    f"mutated progress run for {mutation_name}",
                    timeout=300,
                )
                module_lines = [line for line in progress.splitlines()
                                if line.startswith(f"plan:{module} ")]
                if len(module_lines) != 1:
                    raise AuditError(
                        f"progress output did not contain one plan:{module} summary"
                    )
                for index, sample in targets:
                    if target_result(driver, sample) is not False:
                        raise AuditError(
                            f"sampled target stayed green: "
                            f"{sample.module}:{sample.obligation}"
                        )
                    print(
                        f"[{index:02}/{len(samples)}] {sample.module}:"
                        f"{sample.obligation} green -> red ({sample.mutation})",
                        flush=True,
                    )
                print(
                    f"Mutation {mutation_index:02}/{len(grouped)} isolated and observed; "
                    f"{module_lines[0]}",
                    flush=True,
                )
            finally:
                # The next build sees this restored source plus only its own
                # mutation. The outer finally performs a final pristine build.
                active_guard.restore()
                active_guard = None
        for relative, original in original_sources.items():
            if (ROOT / relative).read_bytes() != original:
                raise AuditError(f"cleanup did not restore {relative}")
        if git_snapshot() != original_git:
            raise AuditError("mutation audit changed the worktree")
        if write_audit is not None:
            write_audit.write_text(render_audit(samples), encoding="utf-8")
            print(f"Wrote {write_audit}", flush=True)
        if verify_audit_path is not None:
            validate_audit(verify_audit_path, samples)
    finally:
        if active_guard is not None:
            active_guard.restore()
        for relative, original in original_sources.items():
            path = ROOT / relative
            if path.read_bytes() != original:
                path.write_bytes(original)
        # A clean executable must be left behind even after interruption/failure.
        build_driver("final pristine driver rebuild")


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    for name in ["validate-manifest", "validate-audit", "run"]:
        sub = subparsers.add_parser(name)
        sub.add_argument("--manifest", type=Path, required=True)
        if name == "validate-audit":
            sub.add_argument("--audit", type=Path, required=True)
        if name == "run":
            modes = sub.add_mutually_exclusive_group()
            modes.add_argument("--write-audit", type=Path)
            modes.add_argument("--verify-audit", type=Path)
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    try:
        samples = parse_manifest(arguments.manifest)
        if arguments.command == "validate-manifest":
            print(
                f"valid manifest: {len(samples)} unique obligations, "
                f"{sum(item.obligation.startswith(RULE_PREFIXES) for item in samples)} "
                f"entity-creation/failure rules, "
                f"{sum(item.boundary for item in samples)} outside-world boundaries"
            )
        elif arguments.command == "validate-audit":
            validate_audit(arguments.audit, samples)
            print(f"valid mutation audit: {arguments.audit}")
        else:
            run_audit(samples, arguments.write_audit, arguments.verify_audit)
        return 0
    except AuditError as error:
        print(f"probe-mutation-check: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Measure Little Ant v1 contract progress without requiring full conformance."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
GENERATED = ROOT / "test-v1" / "generated"
SCENARIOS = ROOT / "test-v1" / "scenarios"
BASELINE_LINE = re.compile(r"^((?:plan|scenario):\S+) (\d+)/(\d+)$")
TOTAL_LINE = re.compile(r"^TOTAL (\d+)/(\d+)$")


class ProgressError(RuntimeError):
    """An error in the progress tool's inputs or environment."""


def read_json(path: Path) -> Any:
    try:
        with path.open(encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, json.JSONDecodeError) as error:
        raise ProgressError(f"cannot read {path.relative_to(ROOT)}: {error}") from error


def item_ids(document: Any, field: str, path: Path) -> list[str]:
    if not isinstance(document, dict) or not isinstance(document.get(field), list):
        raise ProgressError(f"{path.relative_to(ROOT)} has no {field!r} array")
    identifiers: list[str] = []
    for index, item in enumerate(document[field]):
        if not isinstance(item, dict) or not isinstance(item.get("id"), str):
            raise ProgressError(
                f"{path.relative_to(ROOT)} {field}[{index}] has no string id"
            )
        identifiers.append(item["id"])
    duplicates = sorted(
        identifier for identifier in set(identifiers) if identifiers.count(identifier) > 1
    )
    if duplicates:
        raise ProgressError(
            f"{path.relative_to(ROOT)} has duplicate IDs: {', '.join(duplicates)}"
        )
    return identifiers


def resolve_driver() -> Path:
    configured = os.environ.get("LANT_V1_TEST_DRIVER")
    if configured:
        candidate = Path(configured)
        if not candidate.is_file():
            discovered = shutil.which(configured)
            if discovered is None:
                raise ProgressError(
                    "LANT_V1_TEST_DRIVER is not an executable path or command: "
                    f"{configured}"
                )
            candidate = Path(discovered)
    else:
        try:
            result = subprocess.run(
                ["cabal", "list-bin", "exe:lant-v1-test-driver"],
                cwd=ROOT,
                check=False,
                capture_output=True,
                text=True,
                timeout=120,
            )
        except (OSError, subprocess.TimeoutExpired) as error:
            raise ProgressError(f"cannot locate lant-v1-test-driver: {error}") from error
        if result.returncode != 0:
            detail = result.stderr.strip() or result.stdout.strip()
            raise ProgressError(f"cabal list-bin failed: {detail}")
        output_lines = [line.strip() for line in result.stdout.splitlines() if line.strip()]
        if len(output_lines) != 1:
            raise ProgressError(
                "cabal list-bin returned an unexpected driver path: "
                + repr(result.stdout)
            )
        candidate = Path(output_lines[0])

    if not candidate.is_file() or not os.access(candidate, os.X_OK):
        raise ProgressError(f"driver is not executable: {candidate}")
    return candidate


def summarize_ids(identifiers: list[str]) -> str:
    shown = identifiers[:5]
    suffix = "" if len(identifiers) <= len(shown) else f" (+{len(identifiers) - len(shown)} more)"
    return ", ".join(shown) + suffix


def run_request(
    driver: Path, label: str, request: dict[str, Any], expected_ids: list[str]
) -> int:
    """Run one request and count only unique, expected, explicitly passing results."""
    try:
        process = subprocess.run(
            [str(driver)],
            cwd=ROOT,
            input=json.dumps(request, separators=(",", ":")),
            check=False,
            capture_output=True,
            text=True,
            timeout=120,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        print(f"{label}: driver invocation failed: {error}", file=sys.stderr)
        return 0

    if process.returncode != 0:
        detail = process.stderr.strip()
        suffix = f": {detail}" if detail else ""
        print(
            f"{label}: driver exited with status {process.returncode}{suffix}",
            file=sys.stderr,
        )
        return 0

    try:
        response = json.loads(process.stdout)
    except json.JSONDecodeError as error:
        print(f"{label}: malformed driver JSON: {error}", file=sys.stderr)
        return 0

    if (
        not isinstance(response, dict)
        or response.get("protocol_version") != 1
        or not isinstance(response.get("ok"), bool)
        or not isinstance(response.get("results", []), list)
    ):
        print(f"{label}: malformed driver response", file=sys.stderr)
        return 0

    expected = set(expected_ids)
    observed: dict[str, list[bool | None]] = {}
    unexpected: list[str] = []
    malformed_count = 0
    for result in response.get("results", []):
        if not isinstance(result, dict) or not isinstance(result.get("id"), str):
            malformed_count += 1
            continue
        identifier = result["id"]
        passed = result.get("passed")
        valid_passed = passed if isinstance(passed, bool) else None
        observed.setdefault(identifier, []).append(valid_passed)
        if identifier not in expected:
            unexpected.append(identifier)

    duplicates = sorted(
        identifier for identifier, values in observed.items() if len(values) != 1
    )
    missing = sorted(expected.difference(observed))
    if malformed_count:
        print(
            f"{label}: {malformed_count} malformed result entr"
            f"{'y' if malformed_count == 1 else 'ies'} counted as failure",
            file=sys.stderr,
        )
    if duplicates:
        print(
            f"{label}: duplicate result IDs counted as failures: "
            f"{summarize_ids(duplicates)}",
            file=sys.stderr,
        )
    if unexpected:
        print(
            f"{label}: unexpected result IDs counted as failures: "
            f"{summarize_ids(sorted(set(unexpected)))}",
            file=sys.stderr,
        )
    if missing:
        print(
            f"{label}: missing result IDs counted as failures: {summarize_ids(missing)}",
            file=sys.stderr,
        )

    return sum(
        1
        for identifier in expected_ids
        if len(observed.get(identifier, [])) == 1
        and observed[identifier][0] is True
    )


def collect_progress(driver: Path) -> list[tuple[str, int, int]]:
    counts: list[tuple[str, int, int]] = []
    plan_paths = sorted(GENERATED.glob("*.plan.json"))
    if not plan_paths:
        raise ProgressError("no generated v1 plans found")
    for plan_path in plan_paths:
        module = plan_path.name.removesuffix(".plan.json")
        model_path = GENERATED / f"{module}.model.json"
        if not model_path.is_file():
            raise ProgressError(f"missing model for plan {module}: {model_path}")
        plan = read_json(plan_path)
        model = read_json(model_path)
        identifiers = item_ids(plan, "obligations", plan_path)
        request = {
            "protocol_version": 1,
            "request_kind": "allium_plan",
            "module": module,
            "plan": plan,
            "model": model,
        }
        label = f"plan:{module}"
        passed = run_request(driver, label, request, identifiers)
        counts.append((label, passed, len(identifiers)))

    scenario_paths = sorted(SCENARIOS.glob("*.json"))
    if not scenario_paths:
        raise ProgressError("no v1 scenarios found")
    for scenario_path in scenario_paths:
        scenario = read_json(scenario_path)
        if not isinstance(scenario, dict) or not isinstance(scenario.get("id"), str):
            raise ProgressError(f"{scenario_path.relative_to(ROOT)} has no string id")
        identifiers = item_ids(scenario, "assertions", scenario_path)
        request = {
            "protocol_version": 1,
            "request_kind": "scenario",
            "scenario": scenario,
        }
        label = f"scenario:{scenario['id']}"
        passed = run_request(driver, label, request, identifiers)
        counts.append((label, passed, len(identifiers)))

    labels = [label for label, _, _ in counts]
    if len(labels) != len(set(labels)):
        raise ProgressError("duplicate plan or scenario labels")
    return counts


def count_lines(counts: list[tuple[str, int, int]]) -> list[str]:
    lines = [f"{label} {passed}/{total}" for label, passed, total in counts]
    lines.append(
        f"TOTAL {sum(passed for _, passed, _ in counts)}/"
        f"{sum(total for _, _, total in counts)}"
    )
    return lines


def write_baseline(path: Path, lines: list[str]) -> None:
    path = path.resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary_name: str | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", dir=path.parent, delete=False
        ) as handle:
            temporary_name = handle.name
            handle.write("\n".join(lines) + "\n")
        os.replace(temporary_name, path)
    except OSError as error:
        raise ProgressError(f"cannot write baseline {path}: {error}") from error
    finally:
        if temporary_name is not None:
            Path(temporary_name).unlink(missing_ok=True)


def read_baseline(
    path: Path, counts: list[tuple[str, int, int]]
) -> dict[str, tuple[int, int]]:
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as error:
        raise ProgressError(f"cannot read baseline {path}: {error}") from error

    baseline: dict[str, tuple[int, int]] = {}
    for line_number, line in enumerate(lines, start=1):
        match = BASELINE_LINE.fullmatch(line)
        total_match = TOTAL_LINE.fullmatch(line)
        if match:
            label, passed, total = match.groups()
        elif total_match:
            label = "TOTAL"
            passed, total = total_match.groups()
        else:
            raise ProgressError(f"malformed baseline line {line_number}: {line!r}")
        if label in baseline:
            raise ProgressError(f"duplicate baseline label: {label}")
        baseline[label] = (int(passed), int(total))

    expected_totals = {label: total for label, _, total in counts}
    expected_totals["TOTAL"] = sum(expected_totals.values())
    if set(baseline) != set(expected_totals):
        missing = sorted(set(expected_totals).difference(baseline))
        unexpected = sorted(set(baseline).difference(expected_totals))
        raise ProgressError(
            "baseline labels do not match the contract"
            f"; missing={missing}; unexpected={unexpected}"
        )
    for label, expected_total in expected_totals.items():
        passed, total = baseline[label]
        if total != expected_total or passed > total:
            raise ProgressError(
                f"invalid baseline count for {label}: {passed}/{total}; "
                f"expected denominator {expected_total}"
            )
    return baseline


def check_baseline(
    baseline_path: Path, counts: list[tuple[str, int, int]]
) -> bool:
    baseline = read_baseline(baseline_path, counts)
    current = {label: (passed, total) for label, passed, total in counts}
    current["TOTAL"] = (
        sum(passed for _, passed, _ in counts),
        sum(total for _, _, total in counts),
    )
    has_regression = False
    for label in [label for label, _, _ in counts] + ["TOTAL"]:
        passed, _ = current[label]
        baseline_passed, _ = baseline[label]
        delta = passed - baseline_passed
        print(
            f"DELTA {label} {delta:+d} "
            f"(current {passed}, baseline {baseline_passed})"
        )
        has_regression = has_regression or delta < 0
    return not has_regression


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--write", metavar="FILE", type=Path)
    mode.add_argument("--check", metavar="FILE", type=Path)
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    try:
        counts = collect_progress(resolve_driver())
        lines = count_lines(counts)
        print("\n".join(lines))
        if arguments.write is not None:
            write_baseline(arguments.write, lines)
        if arguments.check is not None:
            return 0 if check_baseline(arguments.check, counts) else 1
        return 0
    except ProgressError as error:
        print(f"v1-progress: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Unit tests for the monotonic Little Ant v1 progress gate."""

from __future__ import annotations

import contextlib
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest


MODULE_PATH = Path(__file__).with_name("v1-progress.py")
SPEC = importlib.util.spec_from_file_location("v1_progress", MODULE_PATH)
if SPEC is None or SPEC.loader is None:  # pragma: no cover - import machinery guard
    raise RuntimeError(f"cannot import {MODULE_PATH}")
v1_progress = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(v1_progress)


class DriverResultValidationTests(unittest.TestCase):
    def run_response(self, response: object, expected: list[str]) -> int:
        with tempfile.TemporaryDirectory() as directory:
            driver = Path(directory) / "driver"
            driver.write_text(
                "#!/usr/bin/env python3\n"
                "import json\n"
                f"print(json.dumps({response!r}))\n",
                encoding="utf-8",
            )
            driver.chmod(0o700)
            with contextlib.redirect_stderr(io.StringIO()):
                return v1_progress.run_request(driver, "test", {}, expected)

    def test_counts_only_explicit_unique_expected_passes(self) -> None:
        response = {
            "protocol_version": 1,
            "ok": False,
            "results": [
                {"id": "a", "passed": True},
                {"id": "b", "passed": False},
            ],
        }
        self.assertEqual(self.run_response(response, ["a", "b"]), 1)

    def test_duplicate_expected_id_fails_that_item(self) -> None:
        response = {
            "protocol_version": 1,
            "ok": False,
            "results": [
                {"id": "a", "passed": True},
                {"id": "a", "passed": True},
                {"id": "b", "passed": True},
            ],
        }
        self.assertEqual(self.run_response(response, ["a", "b"]), 1)

    def test_missing_expected_id_is_not_invented(self) -> None:
        response = {
            "protocol_version": 1,
            "ok": False,
            "results": [{"id": "a", "passed": True}],
        }
        self.assertEqual(self.run_response(response, ["a", "b"]), 1)

    def test_unknown_id_invalidates_the_malformed_response(self) -> None:
        response = {
            "protocol_version": 1,
            "ok": True,
            "results": [
                {"id": "a", "passed": True},
                {"id": "invented", "passed": True},
            ],
        }
        self.assertEqual(self.run_response(response, ["a"]), 0)

    def test_malformed_result_invalidates_the_response(self) -> None:
        response = {
            "protocol_version": 1,
            "ok": True,
            "results": [{"passed": True}, {"id": "a", "passed": True}],
        }
        self.assertEqual(self.run_response(response, ["a"]), 0)

    def test_malformed_json_counts_nothing(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            driver = Path(directory) / "driver"
            driver.write_text(
                "#!/usr/bin/env python3\nprint('not-json')\n", encoding="utf-8"
            )
            driver.chmod(0o700)
            with contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(
                    v1_progress.run_request(driver, "test", {}, ["a"]), 0
                )


class BaselineTests(unittest.TestCase):
    def test_check_is_monotonic_per_item(self) -> None:
        counts = [("plan:root", 2, 3), ("scenario:example", 1, 2)]
        baseline_lines = ["plan:root 1/3", "scenario:example 1/2", "TOTAL 2/5"]
        with tempfile.TemporaryDirectory() as directory:
            baseline = Path(directory) / "baseline.txt"
            baseline.write_text("\n".join(baseline_lines) + "\n", encoding="utf-8")
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertTrue(v1_progress.check_baseline(baseline, counts))

    def test_check_rejects_one_regression_even_if_total_is_higher(self) -> None:
        counts = [("plan:root", 0, 3), ("scenario:example", 3, 3)]
        baseline_lines = ["plan:root 1/3", "scenario:example 1/3", "TOTAL 2/6"]
        with tempfile.TemporaryDirectory() as directory:
            baseline = Path(directory) / "baseline.txt"
            baseline.write_text("\n".join(baseline_lines) + "\n", encoding="utf-8")
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertFalse(v1_progress.check_baseline(baseline, counts))


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Tests for the release mutation audit and its fail-closed gate."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parent
sys.path.insert(0, str(TOOLS))
import probe_mutation  # noqa: E402


class ManifestTests(unittest.TestCase):
    def test_checked_in_manifest_meets_release_sampling_policy(self) -> None:
        process = subprocess.run(
            ["bash", "tools/probe-mutation-check.sh", "--validate-only"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(process.returncode, 0, process.stderr)
        self.assertIn("30 unique obligations", process.stdout)
        self.assertIn("24 entity-creation/failure rules", process.stdout)
        self.assertIn("14 outside-world boundaries", process.stdout)

    def test_manifest_validation_rejects_duplicate_targets(self) -> None:
        sample = probe_mutation.Sample(
            "root", "invariant.GloballyOpaqueEntityIds",
            "kernel-opaque-identity", False, "duplicate",
        )
        with self.assertRaisesRegex(probe_mutation.AuditError, "duplicate"):
            probe_mutation.validate_manifest([sample] * 30)


class TargetResultTests(unittest.TestCase):
    target = "rule-failure.Example.1"

    def response(self, results: object, ok: object = True) -> object:
        return {"protocol_version": 1, "ok": ok, "results": results}

    def test_detects_exact_green_and_red_target(self) -> None:
        self.assertTrue(probe_mutation.evaluate_target_response(
            self.response([{"id": self.target, "passed": True}]), self.target))
        self.assertFalse(probe_mutation.evaluate_target_response(
            self.response([{"id": self.target, "passed": False}], False), self.target))

    def test_rejects_missing_duplicate_malformed_and_unrelated_results(self) -> None:
        invalid = [
            self.response([]),
            self.response([
                {"id": self.target, "passed": True},
                {"id": self.target, "passed": True},
            ]),
            self.response([{"id": self.target, "passed": "yes"}]),
            self.response([{"id": "rule-failure.Unrelated.1", "passed": False}], False),
        ]
        for response in invalid:
            with self.subTest(response=response):
                with self.assertRaises(probe_mutation.AuditError):
                    probe_mutation.evaluate_target_response(response, self.target)

    def test_rejects_ok_flag_that_hides_a_red_target(self) -> None:
        with self.assertRaisesRegex(probe_mutation.AuditError, "ok flag"):
            probe_mutation.evaluate_target_response(
                self.response([{"id": self.target, "passed": False}], True), self.target)


class CleanupTests(unittest.TestCase):
    def test_mutation_guard_restores_source_after_failure(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "Behavior.hs"
            source.write_text("real behavior\n", encoding="utf-8")
            mutation = probe_mutation.Mutation(
                "Behavior.hs", "real behavior", "mutated behavior"
            )
            with self.assertRaisesRegex(RuntimeError, "interrupt"):
                with probe_mutation.MutationGuard(root, mutation):
                    self.assertEqual(source.read_text(encoding="utf-8"), "mutated behavior\n")
                    raise RuntimeError("interrupt")
            self.assertEqual(source.read_text(encoding="utf-8"), "real behavior\n")


class AuditGateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        process = subprocess.run(
            ["bash", "tools/probe-mutation-check.sh", "--print-manifest"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=True,
        )
        cls.directory = tempfile.TemporaryDirectory()
        cls.manifest = Path(cls.directory.name) / "manifest.tsv"
        cls.manifest.write_text(process.stdout, encoding="utf-8")
        cls.samples = probe_mutation.parse_manifest(cls.manifest)

    @classmethod
    def tearDownClass(cls) -> None:
        cls.directory.cleanup()

    def test_audit_validator_accepts_complete_current_report(self) -> None:
        path = Path(self.directory.name) / "valid.md"
        path.write_text(probe_mutation.render_audit(self.samples), encoding="utf-8")
        probe_mutation.validate_audit(path, self.samples)

    def test_audit_validator_fails_closed_for_missing_stale_or_fake_report(self) -> None:
        missing = Path(self.directory.name) / "missing.md"
        with self.assertRaisesRegex(probe_mutation.AuditError, "missing"):
            probe_mutation.validate_audit(missing, self.samples)

        stale = Path(self.directory.name) / "stale.md"
        stale.write_text(probe_mutation.render_audit(self.samples).replace(
            "- Implementation SHA-256: `", "- Implementation SHA-256: `stale-", 1
        ), encoding="utf-8")
        with self.assertRaisesRegex(probe_mutation.AuditError, "stale"):
            probe_mutation.validate_audit(stale, self.samples)

        fake = Path(self.directory.name) / "fake.md"
        fake.write_text(probe_mutation.render_audit(self.samples).replace(
            "None.", "rule-failure.Fake.1 stayed green.", 1
        ), encoding="utf-8")
        with self.assertRaisesRegex(probe_mutation.AuditError, "unacknowledged"):
            probe_mutation.validate_audit(fake, self.samples)

    def test_story_gate_orders_mutation_check_after_full_progress_detection(self) -> None:
        gate = (ROOT / "tools/story-gate.sh").read_text(encoding="utf-8")
        detection = gate.index("if awk")
        audit_validation = gate.index("probe-mutation-check.sh --validate-audit")
        mutation_run = gate.index("probe-mutation-check.sh --verify-audit")
        self.assertLess(detection, audit_validation)
        self.assertLess(audit_validation, mutation_run)


class ReleaseDocumentationTests(unittest.TestCase):
    def test_release_metadata_and_guides_name_final_gates(self) -> None:
        cabal = (ROOT / "little-ant.cabal").read_text(encoding="utf-8")
        self.assertRegex(cabal, r"(?m)^version:\s+1\.0\.0\.0$")
        for relative in ["README.md", "CHANGELOG.md", "test-v1/README.md"]:
            text = (ROOT / relative).read_text(encoding="utf-8")
            with self.subTest(path=relative):
                self.assertIn("1566/1566", text)
                self.assertIn("probe-mutation-check.sh", text)
                self.assertIn("synthetic", text.lower())
                self.assertNotIn("intentionally red", text.lower())
                self.assertNotIn("future internal Haskell", text)


if __name__ == "__main__":
    unittest.main()

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

import lant_conformance as conformance  # noqa: E402


class CatalogTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.catalog = conformance.discover_catalog(ROOT / "spec")

    def test_complete_catalog_is_unique(self) -> None:
        self.assertEqual(1183, len(self.catalog))
        self.assertEqual(894, sum(item.catalog == "rule" for item in self.catalog.values()))
        self.assertEqual(217, sum(item.catalog == "screen" for item in self.catalog.values()))
        self.assertEqual(72, sum(item.catalog == "scenario" for item in self.catalog.values()))

    def test_canonical_ranges_expand_exactly(self) -> None:
        self.assertEqual(
            ["PRD-006", "PRD-007", "PRD-008", "PRD-009"],
            conformance.expand_range("PRD-006..009", self.catalog),
        )
        self.assertEqual(
            ["UX-F04", "UX-F05"],
            conformance.expand_range("UX-F04..F05", self.catalog),
        )

    def test_unknown_packet_identifier_is_rejected(self) -> None:
        with self.assertRaises(conformance.ConformanceError):
            conformance.build_packet(ROOT, ["PRD-999"], [])

    def test_duplicate_definition_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "one.md").write_text("- **PRD-001 — First.** One.\n", encoding="utf-8")
            (root / "two.md").write_text("- **PRD-001 — Again.** Two.\n", encoding="utf-8")
            with self.assertRaisesRegex(conformance.ConformanceError, "duplicate"):
                conformance.discover_catalog(root)

    def test_every_flow_has_one_owner(self) -> None:
        flows = conformance.parse_flow_rows(ROOT / "spec/little-ant-1.0/ux/flow-coverage.md")
        self.assertEqual(65, len(flows))
        rows = conformance.audit_flow_coverage(flows, ROOT / "implementation/coverage.tsv")
        self.assertEqual(65, len(rows))

    def test_every_definition_has_one_owner(self) -> None:
        conformance.audit_owners(self.catalog, ROOT / "conformance/catalog-owners.tsv")


class EvidenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.catalog = conformance.discover_catalog(ROOT / "spec")

    def descriptor(self, identifier: str) -> dict[str, object]:
        return {
            "evidence_id": "FIXTURE-001",
            "rules": [identifier],
            "screens": [],
            "flow": None,
            "kind": "protocol",
            "spec_hashes": {identifier: self.catalog[identifier].digest},
            "obligations": sorted(conformance.required_obligations(self.catalog[identifier])),
        }

    def test_stale_hash_demotes_verified_evidence(self) -> None:
        descriptor = self.descriptor("PRD-002")
        descriptor["spec_hashes"] = {"PRD-002": "sha256:" + "0" * 64}
        with self.assertRaisesRegex(conformance.ConformanceError, "demoted"):
            conformance.validate_descriptor(descriptor, self.catalog)

    def test_missing_negative_obligation_is_rejected(self) -> None:
        descriptor = self.descriptor("PRD-013")
        descriptor["obligations"] = []
        with self.assertRaisesRegex(conformance.ConformanceError, "negative"):
            conformance.validate_descriptor(descriptor, self.catalog)


    def test_repository_evidence_registry_is_valid_and_unique(self) -> None:
        evidence = conformance.audit_evidence(ROOT / "conformance/evidence.json", self.catalog)
        identifiers = [descriptor["evidence_id"] for descriptor in evidence]
        self.assertGreater(len(identifiers), 0)
        self.assertEqual(len(identifiers), len(set(identifiers)))

class GuardTests(unittest.TestCase):
    def test_rejected_public_command_is_detected(self) -> None:
        failures = conformance.vocabulary_violations_for_text(
            "src/Bad.hs",
            'commandName = "/capture"',
            {"/capture"},
            {"capture"},
            [],
            True,
        )
        self.assertTrue(failures)

    def test_command_substring_in_asset_name_is_not_rejected(self) -> None:
        failures = conformance.vocabulary_violations_for_text(
            "README.md",
            "assets/importance-curve.svg",
            {"/importance"},
            set(),
            [],
            False,
        )
        self.assertEqual([], failures)

    def test_full_audit_reports_exact_inventory(self) -> None:
        report = conformance.full_audit(ROOT)
        self.assertEqual(
            {"definitions": 1183, "rules": 894, "screens": 217, "scenarios": 72, "flows": 65},
            report,
        )


if __name__ == "__main__":
    unittest.main()

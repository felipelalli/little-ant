from __future__ import annotations

import csv
import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

import evidence_status  # noqa: E402
import lant_conformance as conformance  # noqa: E402


class OwnershipFailureTests(unittest.TestCase):
    def test_deleting_an_owner_selector_fails_totality(self) -> None:
        catalog = conformance.discover_catalog(ROOT / "spec")
        rows = conformance.read_tsv(ROOT / "conformance/catalog-owners.tsv")
        with tempfile.TemporaryDirectory() as directory:
            candidate = Path(directory) / "owners.tsv"
            with candidate.open("w", encoding="utf-8", newline="") as handle:
                writer = csv.DictWriter(handle, fieldnames=rows[0].keys(), delimiter="\t")
                writer.writeheader()
                writer.writerows(
                    row for row in rows if not (row["catalog"] == "rule" and row["prefix"] == "PRD")
                )
            with self.assertRaisesRegex(conformance.ConformanceError, "has 0 owners"):
                conformance.audit_owners(catalog, candidate)


class CalculationVectorTests(unittest.TestCase):
    def test_vector_file_tracks_the_normative_profile_bytes(self) -> None:
        vectors = json.loads((ROOT / "conformance/calculation-vectors.json").read_text(encoding="utf-8"))
        profile = (ROOT / "spec/little-ant-1.0/deterministic-calculation-profile.md").read_bytes()
        self.assertEqual(hashlib.sha256(profile).hexdigest(), vectors["profile_sha256"])
        self.assertEqual("little-ant/calculation-vectors@1", vectors["schema"])

    def test_reference_weight_and_singleton_vectors_are_present(self) -> None:
        vectors = json.loads((ROOT / "conformance/calculation-vectors.json").read_text(encoding="utf-8"))
        by_id = {item["id"]: item for item in vectors["vectors"]}
        self.assertEqual(1_337_500, by_id["weighted-choice/neutral-siblings"]["expected"]["total"])
        self.assertEqual("B", by_id["weighted-choice/signals-and-sample"]["expected"]["selected"])
        self.assertEqual(0, by_id["weighted-choice/singleton"]["expected"]["blocks_consumed"])


class AutomaticDemotionTests(unittest.TestCase):
    def test_stale_verified_flow_is_reported_as_implemented(self) -> None:
        rows = [
            {
                "gate": "3",
                "flow": "Feed text input",
                "owner_slice": "S01",
                "status": "verified",
                "evidence": "E-STALE",
            }
        ]
        evidence = [{"evidence_id": "E-STALE"}]

        def reject(_: object) -> None:
            raise RuntimeError("stale hash")

        effective = evidence_status.effective_coverage(rows, evidence, reject)
        self.assertEqual("implemented", effective[0]["status"])
        self.assertEqual("verified", effective[0]["declared_status"])
        self.assertIn("stale hash", effective[0]["demotion_reasons"][0])


if __name__ == "__main__":
    unittest.main()

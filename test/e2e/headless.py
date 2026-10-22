"""Exercise the public CLI without a REPL or internal engine APIs."""

from __future__ import annotations

import json
import os
from pathlib import Path
import pty
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class HeadlessTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.executable = os.environ.get("LANT_EXECUTABLE") or subprocess.check_output(
            ["cabal", "list-bin", "exe:lant"], cwd=ROOT, text=True
        ).strip()
        cls.runner = subprocess.check_output(
            ["cabal", "list-bin", "exe:lant-pack-runner"], cwd=ROOT, text=True
        ).strip()

    def setUp(self):
        self.folder = tempfile.TemporaryDirectory(prefix="lant-headless-")
        self.root = Path(self.folder.name)
        self.environment = os.environ.copy()
        self.environment.update(
            {f"XDG_{name.upper()}_HOME": str(self.root / name) for name in ("config", "data", "state")}
        )
        self.environment.update(
            XDG_RUNTIME_DIR=str(self.root / "runtime"),
            little_ant_datadir=str(ROOT),
            PATH=str(Path(self.runner).parent) + os.pathsep + self.environment["PATH"],
        )
        self.serial = 0

    def tearDown(self):
        self.folder.cleanup()

    def call(self, *arguments, content="", code=None):
        result = subprocess.run(
            [self.executable, "--non-interactive", "--json", *arguments],
            input=content, capture_output=True, text=True, cwd=ROOT,
            env=self.environment, timeout=15,
        )
        if code is not None:
            self.assertEqual(result.returncode, code, result.stdout + result.stderr)
        else:
            self.assertIn(result.returncode, (0, 2), result.stdout + result.stderr)
        return result, json.loads(result.stderr if result.returncode == 1 else result.stdout)

    def snapshot(self, value):
        self.serial += 1
        path = self.root / f"interaction-{self.serial}.json"
        path.write_text(json.dumps(value))
        return str(path)

    def reply(self, value, action, text=None, code=None):
        arguments = ["interaction", "respond", "--from", self.snapshot(value), "--action", action]
        if text is not None:
            arguments += ["--text", text]
        return self.call(*arguments, code=code)

    def create_work(self, title):
        _, value = self.call("feed", title, code=0)
        for action in ("raw.materialize-work", "nature.choose.atomic_task", "template.setting.digital", "template.choose.digital_task"):
            _, value = self.reply(value, action, code=2)
        _, value = self.reply(value, "work.title.submit", title, code=2)
        while value["interaction"]["opportunity"]["type"] != "work_preview":
            _, value = self.reply(value, "importance.less", code=2)
        self.reply(value, "work.create", code=0)
        _, hits = self.call("search", title, code=0)
        return next(hit["handle"] for hit in hits["hits"] if hit["kind"] == "brick")

    def event_types(self):
        _, history = self.call("history", "100", code=0)
        return [event for entry in history["history"] for event in entry["event_types"]]

    def test_noninteractive_never_starts_the_repl(self):
        _, error = self.call(code=1)
        self.assertEqual(error["code"], "invalid_input")

    def test_noninteractive_does_not_prompt_even_with_a_real_terminal(self):
        master, slave = pty.openpty()
        try:
            for arguments in (("feed",), ("vault", "create", "--without-backup")):
                result = subprocess.run(
                    [self.executable, "--non-interactive", "--json", *arguments],
                    stdin=slave, capture_output=True, text=True, env=self.environment,
                    cwd=ROOT, timeout=5,
                )
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn(json.loads(result.stderr)["code"], ("invalid_input", "permission_required"))
        finally:
            os.close(master)
            os.close(slave)

    def test_archive_restore_and_update_need_no_focus_or_terminal(self):
        handle = self.create_work("Archive directly")
        _, pending = self.call("archive", handle, code=2)
        self.assertEqual(pending["status"], "awaiting_input")
        self.assertEqual(pending["interaction"]["opportunity"]["type"], "archive_preview")
        before = self.event_types()
        _, archived = self.call("archive", handle, "--yes", code=0)
        self.assertEqual(archived["status"], "completed")
        self.assertEqual(self.event_types()[len(before):], ["brick_status_changed", "lazy_review_requested"])
        _, shown = self.call("show", handle, code=0)
        self.assertIn("Status: archived", shown["details"])
        self.call("restore", handle, "--yes", code=0)
        self.call("update", handle, "title", "--text", "A new title", "--yes", code=0)
        self.call("update", handle, "description", "--text-file", "-", "--yes", content="First line\n\nSecond line\n", code=0)
        _, shown = self.call("--view", "operational", "show", handle, code=0)
        self.assertIn("A new title", shown["title"])
        self.assertIn("First line\n\nSecond line", "\n".join(shown["details"]))
        self.assertFalse(any("focus" in event for event in self.event_types()))

    def test_bound_response_rejects_stale_replayed_and_tampered_inputs(self):
        _, old = self.call("feed", "First material", code=0)
        _, current = self.call("feed", "Second material", code=0)
        before = self.event_types()
        _, error = self.reply(old, "raw.materialize-work", code=1)
        self.assertEqual(error["code"], "stale_interaction")
        self.assertEqual(self.event_types(), before)
        self.reply(current, "raw.materialize-work", code=2)
        self.reply(current, "raw.materialize-work", code=1)
        current["interaction"]["content"]["heading"] = "Tampered"
        _, error = self.reply(current, "raw.materialize-work", code=1)
        self.assertEqual(error["code"], "invalid_input")

    def test_pending_inspection_preserves_checkpoint_and_randomness(self):
        self.call("feed", "Inspect without drawing", code=0)
        checkpoint = self.root / "state/lant/profiles/default/dataset/checkpoints/pending-envelope.json"
        before = checkpoint.read_bytes()
        history = self.event_types()
        _, pending = self.call("interaction", "show", code=0)
        self.assertEqual(pending["status"], "awaiting_input")
        self.assertEqual(checkpoint.read_bytes(), before)
        self.assertEqual(self.event_types(), history)

    def test_dry_run_direct_updates_and_archive_preserve_every_dataset_byte(self):
        handle = self.create_work("Preserve dry run")
        dataset = self.root / "state/lant/profiles/default/dataset"
        original = {str(p.relative_to(dataset)): p.read_bytes() for p in dataset.rglob("*") if p.is_file()}
        for arguments in (
            ("archive", handle, "--yes"),
            ("update", handle, "title", "--text", "Simulated title", "--yes"),
            ("update", handle, "description", "--text", "Simulated description", "--yes"),
        ):
            _, result = self.call("--dry-run", *arguments, code=0)
            self.assertTrue(result["dry_run"])
            self.assertEqual(result["status"], "simulated")
        after = {str(p.relative_to(dataset)): p.read_bytes() for p in dataset.rglob("*") if p.is_file()}
        self.assertEqual(after, original)

    def test_update_preview_can_be_declined_without_changing_title(self):
        handle = self.create_work("Keep the title")
        _, pending = self.call("update", handle, "title", "--text", "Do not save", code=2)
        self.assertEqual(pending["interaction"]["opportunity"]["type"], "update_preview")
        self.reply(pending, "update.cancel", code=2)
        _, shown = self.call("show", handle, code=0)
        self.assertEqual(shown["title"], "Keep the title")

    def test_navigation_is_available_without_a_terminal(self):
        _, raw = self.call("feed", "Navigate a draft", code=0)
        _, nature = self.reply(raw, "raw.materialize-work", code=2)
        _, previous = self.call("interaction", "back", "--from", self.snapshot(nature), code=2)
        self.assertEqual(previous["interaction"]["opportunity"], raw["interaction"]["opportunity"])
        _, restored = self.call("interaction", "forward", "--from", self.snapshot(previous), code=2)
        self.assertEqual(restored["interaction"]["opportunity"], nature["interaction"]["opportunity"])

    def test_focus_judgment_and_completion_use_the_same_public_response_route(self):
        handle = self.create_work("Review a concrete decision")
        _, effort = self.call("effort", handle, code=2)
        self.reply(effort, "effort.class.normal", code=0)
        _, phase = self.call("phase", handle, code=2)
        self.reply(phase, "phase.execution", code=0)
        _, focus = self.call("focus", handle, code=2)
        self.reply(focus, "focus.accept", code=0)
        self.call("pause", code=0)
        self.call("done", handle, code=0)
        _, shown = self.call("show", handle, code=0)
        self.assertIn("Status: done", shown["details"])

    def test_import_confirmation_is_scriptable_and_preserves_the_source(self):
        source = self.root / "notes.txt"
        source.write_text("Imported evidence\n")
        _, preview = self.call("import", str(source), "--snapshot", code=2)
        _, receipt = self.reply(preview, "import.accept", code=0)
        self.assertEqual(source.read_text(), "Imported evidence\n")
        self.assertEqual(len(receipt["interaction"]["opportunity"]["imported_raw_ids"]), 1)
        _, diagnostic = self.call("doctor", code=0)
        self.assertTrue(diagnostic["healthy"])

    def test_invalid_input_and_unimplemented_commands_fail_without_a_prompt(self):
        _, raw = self.call("feed", "Keep this question", code=0)
        before = self.event_types()
        self.reply(raw, "archive.accept", code=1)
        self.call("update", "#missing", "--yes", code=1)
        for arguments in (("web",), ("editor",), ("merge", "#one", "#two"), ("supersede", "#one", "#two"), ("packs", "untrust", "example.pack")):
            _, error = self.call(*arguments, code=1)
            self.assertEqual(error["code"], "unsupported")
        self.assertEqual(self.event_types(), before)

    def test_stdin_accepts_bound_json_or_exact_text_without_ambiguity(self):
        _, raw = self.call("feed", content="Exact material from stdin\n", code=0)
        self.call("interaction", "respond", "--from", "-", "--action", "raw.materialize-work", content=json.dumps(raw), code=2)
        self.call("interaction", "respond", "--from", "-", "--action", "work.title.submit", "--text-file", "-", content=json.dumps(raw), code=1)

    def test_an_existing_raw_can_be_opened_directly_without_a_draw(self):
        _, first = self.call("feed", "First selected material", code=0)
        self.call("feed", "Another pending material", code=0)
        before = self.event_types()
        _, opened = self.call("--view", "guided", "show", first["raw"]["handle"], code=2)
        self.assertEqual(opened["interaction"]["opportunity"]["raw_id"], first["raw"]["id"])
        self.assertEqual(self.event_types(), before)

    def test_triage_opens_the_raw_question_directly_without_a_draw(self):
        _, empty = self.call("triage", code=1)
        self.assertEqual((empty["code"], empty["recovery"][0]["id"]), ("precondition_failed", "feed"))
        self.create_work("Material already shaped into Work")
        _, shaped = self.call("search", "Material already shaped into Work", code=0)
        shaped_raw = next(hit["handle"] for hit in shaped["hits"] if hit["kind"] == "raw")
        _, first = self.call("feed", "First material awaiting triage", code=0)
        _, second = self.call("feed", "Second material awaiting triage", code=0)
        before = self.event_types()
        _, opened = self.call("triage", code=2)
        self.assertEqual(opened["interaction"]["opportunity"]["type"], "raw_triage")
        self.assertEqual(opened["interaction"]["opportunity"]["raw_id"], first["raw"]["id"])
        _, named = self.call("triage", second["raw"]["handle"], code=2)
        self.assertEqual(named["interaction"]["opportunity"]["raw_id"], second["raw"]["id"])
        _, settled = self.call("triage", shaped_raw, code=1)
        self.assertEqual(settled["code"], "precondition_failed")
        self.assertEqual(self.event_types(), before)

    def test_noninteractive_vault_input_is_explicit_and_redacted(self):
        _, error = self.call("vault", "create", "--without-backup", code=1)
        self.assertEqual(error["code"], "permission_required")
        secret = "headless-test-passphrase-unique"
        result, _ = self.call("--secret-stdin", "vault", "create", "--without-backup", content=f"{secret}\n{secret}\n", code=0)
        self.assertNotIn(secret, result.stdout + result.stderr)
        result, _ = self.call("--secret-stdin", "vault", "unlock", content=f"{secret}\n", code=0)
        self.assertNotIn(secret, result.stdout + result.stderr)
        self.call("vault", "lock", code=0)


if __name__ == "__main__":
    unittest.main()

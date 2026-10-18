"""Exercise the shipped REPL in a real PTY using only the Python standard library."""

from __future__ import annotations

import codecs
import errno
import fcntl
import json
import os
from pathlib import Path
import pty
import re
import select
import signal
import struct
import subprocess
import tempfile
import termios
import time
import unittest


ROOT = Path(__file__).resolve().parents[2]


class Terminal:
    """Interpret the cursor movement and erasure emitted by Vty's xterm backend."""

    def __init__(self, columns: int, rows: int):
        self.columns, self.rows = columns, rows
        self.x = self.y = 0
        self.grid = [[" "] * columns for _ in range(rows)]
        self.pending = ""
        self.decoder = codecs.getincrementaldecoder("utf-8")("replace")

    def feed(self, data: bytes):
        text = self.pending + self.decoder.decode(data)
        self.pending = ""
        index = 0
        while index < len(text):
            character = text[index]
            if character == "\x1b":
                if index + 1 == len(text):
                    break
                if text[index + 1] == "[":
                    match = re.match(r"\x1b\[([0-?]*)([ -/]*)([@-~])", text[index:])
                    if not match:
                        break
                    self.control(match[1], match[3])
                    index += len(match[0])
                    continue
                if text[index + 1] in "()":
                    if index + 2 == len(text):
                        break
                    index += 3
                    continue
                index += 2
                continue
            if character == "\r":
                self.x = 0
            elif character == "\n":
                self.y = min(self.rows - 1, self.y + 1)
            elif character == "\b":
                self.x = max(0, self.x - 1)
            elif character >= " ":
                if self.x >= self.columns:
                    self.x = 0
                    self.y = min(self.rows - 1, self.y + 1)
                self.grid[self.y][self.x] = character
                self.x += 1
            index += 1
        self.pending = text[index:]

    def control(self, parameters: str, command: str):
        private = parameters.startswith("?")
        values = [int(value or 0) for value in parameters.lstrip("?").split(";")]
        amount = values[0] or 1
        if command in "Hf":
            self.y = min(self.rows - 1, max(0, amount - 1))
            self.x = min(self.columns - 1, max(0, (values[1] if len(values) > 1 else 1) - 1))
        elif command == "G":
            self.x = min(self.columns - 1, amount - 1)
        elif command == "A":
            self.y = max(0, self.y - amount)
        elif command == "B":
            self.y = min(self.rows - 1, self.y + amount)
        elif command == "C":
            self.x = min(self.columns - 1, self.x + amount)
        elif command == "D":
            self.x = max(0, self.x - amount)
        elif command == "J":
            if values[0] in (2, 3):
                self.grid = [[" "] * self.columns for _ in range(self.rows)]
            else:
                self.grid[self.y][self.x:] = [" "] * (self.columns - self.x)
                for row in range(self.y + 1, self.rows):
                    self.grid[row] = [" "] * self.columns
        elif command == "K":
            start, end = (0, self.columns) if values[0] == 2 else (0, self.x + 1) if values[0] == 1 else (self.x, self.columns)
            self.grid[self.y][start:end] = [" "] * (end - start)
        elif command == "X":
            end = min(self.columns, self.x + amount)
            self.grid[self.y][self.x:end] = [" "] * (end - self.x)
        elif command == "h" and private and 1049 in values:
            self.grid = [[" "] * self.columns for _ in range(self.rows)]
            self.x = self.y = 0

    @property
    def text(self):
        return "\n".join("".join(row).rstrip() for row in self.grid)


class Repl:
    def __init__(self, executable: str, environment: dict[str, str], columns=80, rows=24):
        self.terminal = Terminal(columns, rows)
        self.closed = False
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            fcntl.ioctl(1, termios.TIOCSWINSZ, struct.pack("HHHH", rows, columns, 0, 0))
            os.execve(executable, [executable], environment)

    def send(self, value: str):
        os.write(self.fd, value.encode())

    def wait(self, phrase: str, timeout=10):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if phrase in self.terminal.text:
                return
            readable, _, _ = select.select([self.fd], [], [], 0.1)
            if readable:
                try:
                    output = os.read(self.fd, 65536)
                except OSError as error:
                    if error.errno == errno.EIO:
                        break
                    raise
                if not output:
                    break
                self.terminal.feed(output)
        raise AssertionError(f"REPL did not show {phrase!r}:\n{self.terminal.text}")

    def close(self):
        if self.closed:
            return
        self.closed = True
        self.send("\x03")
        self.await_exit("Ctrl-C")

    def await_exit(self, gesture: str):
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            pid, status = os.waitpid(self.pid, os.WNOHANG)
            if pid:
                self.closed = True
                os.close(self.fd)
                if os.waitstatus_to_exitcode(status) != 0:
                    raise AssertionError(f"REPL exited with status {status}")
                return
            time.sleep(0.02)
        os.kill(self.pid, signal.SIGKILL)
        os.waitpid(self.pid, 0)
        self.closed = True
        os.close(self.fd)
        raise AssertionError(f"{gesture} did not exit the REPL")


class ReplTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.executable = subprocess.check_output(["cabal", "list-bin", "exe:lant"], cwd=ROOT, text=True).strip()
        cls.runner = subprocess.check_output(["cabal", "list-bin", "exe:lant-pack-runner"], cwd=ROOT, text=True).strip()

    def setUp(self):
        self.folder = tempfile.TemporaryDirectory(prefix="lant-repl-")
        self.root = Path(self.folder.name)
        self.environment = os.environ.copy()
        self.environment.update({f"XDG_{name.upper()}_HOME": str(self.root / name) for name in ("config", "data", "state")})
        self.environment.update(TERM="xterm-256color", NO_COLOR="1", XDG_RUNTIME_DIR=str(self.root / "runtime"), little_ant_datadir=str(ROOT), PATH=str(Path(self.runner).parent) + os.pathsep + self.environment["PATH"])
        self.repl = None

    def tearDown(self):
        try:
            if self.repl:
                self.repl.close()
        finally:
            self.folder.cleanup()

    def launch(self, columns=80, rows=24):
        self.repl = Repl(self.executable, self.environment, columns, rows)
        self.repl.wait("No Bricks yet.")

    def cli(self, *arguments):
        return json.loads(subprocess.check_output([self.executable, "--json", *arguments], env=self.environment, cwd=ROOT, text=True))

    def test_browse_and_cancel_search_preserve_an_unsubmitted_feed(self):
        self.launch()
        self.repl.send("/list\r")
        self.repl.wait("Importance order")
        self.repl.wait("Ctrl+F search")
        self.repl.wait("[i]mportance · [f]orecast · [a]genda")
        self.repl.send("f")
        self.repl.wait("Focus forecast")
        self.repl.send("c")
        self.repl.wait("Categories + parts")
        self.repl.send("\x06fc")
        self.repl.wait("Search: fc")
        self.repl.wait("Focus forecast")
        self.repl.send("\x06")
        self.repl.wait("Ctrl+F search")
        self.repl.send("a")
        self.repl.wait("Agenda")
        self.repl.wait("[c]ategories: on")
        self.repl.send("\x1b[D")
        self.repl.wait("Focus forecast")
        self.repl.send("\x1b[C")
        self.repl.wait("Agenda")
        self.repl.send("i")
        self.repl.wait("Importance order")
        self.repl.wait("Search: fc")
        self.repl.send("\x06a")
        self.repl.wait("Search: fca")
        self.repl.send("\x1b")
        self.repl.wait("Ctrl+F search")
        self.repl.wait("Categories + parts")
        self.repl.send("\x1b")
        self.repl.wait("No Bricks yet.")
        self.repl.send("f")
        self.repl.wait("Feed Little Ant")
        self.repl.send("\x1b[200~Keep this draft\x1b[201~")
        self.repl.wait("Keep this draft")
        self.repl.send("\x06")
        self.repl.wait("typed handles")
        self.repl.send("absent\r")
        self.repl.wait("Search: absent")
        self.repl.send("\x1b")
        self.repl.wait("Keep this draft")
        self.assertEqual(list(self.root.glob("state/lant/profiles/default/dataset/events/*.jsonl")), [])

    def test_create_inspect_scroll_focus_and_complete_through_the_palette(self):
        self.launch()
        material = "Fix the REPL\n" + "\n".join(f"Evidence line {index}" for index in range(40)) + "\nEND_OF_MATERIAL"
        self.cli("feed", material)
        # Restart to load the durable Raw triage instead of the pristine envelope.
        self.repl.close()
        self.repl = Repl(self.executable, self.environment)
        self.repl.wait("Review raw material")
        self.repl.send("y")
        self.repl.wait("How should this behave?")
        self.repl.send("a")
        self.repl.wait("Where is it done?")
        self.repl.send("\r")
        self.repl.wait("a digital [t]ask")
        self.repl.send("\r")
        self.repl.wait("write Brick titles")
        self.repl.send("\r")
        self.repl.wait("Create this Work?")
        self.repl.send("y")
        self.repl.wait("Created:")
        handle = self.cli("search", "REPL")["hits"][0]["handle"]
        self.repl.send("\x06" + handle + "\r")
        self.repl.wait("Search: " + handle)
        self.repl.send("\r")
        self.repl.wait("Kind: brick")
        self.repl.send("\x1b[F")
        self.repl.wait("END_OF_MATERIAL")
        self.repl.send("\x1b")
        self.repl.wait("Search: " + handle)
        self.repl.send("\r")
        self.repl.wait("Kind: brick")
        self.repl.send("f")
        self.repl.wait("Focus?")
        self.repl.send("y")
        self.repl.wait("Current focus:")
        self.repl.send("\x1b")
        self.repl.wait("Undo the last recorded action?")
        self.repl.send("\x1b")
        self.repl.await_exit("Escape at current focus")
        self.repl = Repl(self.executable, self.environment)
        self.repl.wait("Current focus:")
        self.repl.send("/done\r")
        self.repl.wait("Nothing needs attention right now.")
        self.repl.wait("✓ Completed:")
        self.assertIn(handle, self.repl.terminal.text)
        self.assertTrue(self.cli("doctor")["healthy"])
        self.assertIn("Status: done", self.cli("show", handle)["details"])

    def create_atomic_work(self, title: str, below=False):
        if self.repl:
            self.repl.close()
        self.cli("feed", title)
        self.repl = Repl(self.executable, self.environment)
        self.repl.wait("Review raw material")
        for gesture, phrase in (("y", "How should this behave?"), ("a", "Where is it done?"), ("d", "a digital [t]ask"), ("t", "write Brick titles")):
            self.repl.send(gesture)
            self.repl.wait(phrase)
        self.repl.send(title + "\r")
        if below:
            self.repl.wait("Is this proposed Work")
            self.repl.send("l")
        self.repl.wait("Create this Work?")
        self.repl.send("y")
        self.repl.wait("Created:")
        return next(hit["handle"] for hit in self.cli("search", title)["hits"] if hit["kind"] == "brick")

    def test_agenda_shows_today_done_and_searches_past_days_above_its_top(self):
        handle = self.create_atomic_work("Finish this earlier")
        self.repl.close()
        self.cli("done", handle)
        self.repl = Repl(self.executable, self.environment, columns=100, rows=40)
        self.repl.wait("Completed:")
        self.repl.send("/list\r")
        self.repl.wait("Importance order")
        self.repl.send("a")
        self.repl.wait("Agenda")
        # Today starts at midnight, so what was done today is already there.
        self.repl.wait(handle)
        self.repl.wait("· done")
        self.repl.wait(". done · × missed")
        # Above the top the agenda searches earlier days; this dataset has none.
        self.repl.send("\x1b[A")
        self.repl.wait("Nothing earlier was recorded in the last 420 days.")
        self.repl.wait(handle)

    def test_completed_work_takes_an_earlier_time_from_the_calendar(self):
        handle = self.create_atomic_work("Attend the onboarding")
        self.repl.close()
        self.cli("done", handle)
        self.repl = Repl(self.executable, self.environment, columns=100, rows=40)
        self.repl.wait("done earlier? /update " + handle)
        self.repl.send("/update " + handle + "\r")
        self.repl.wait("[w]hen done")
        self.repl.send("w")
        self.repl.wait("When was it done?")
        self.repl.wait("Home today")
        self.repl.send("\x1b[C")
        self.repl.wait("Work cannot be done in the future.")
        self.repl.send("\x1b[D")
        self.repl.send("\r")
        self.repl.wait("Time (HH:MM)")
        self.repl.send("\r")
        self.repl.wait("Record when this was done?")
        self.repl.wait("UTC")
        self.repl.send("y")
        self.repl.wait("Done on:")
        self.repl.send("/agenda\r")
        self.repl.wait("Agenda")
        self.repl.wait(". done")

    def test_escape_after_an_action_offers_to_undo_it(self):
        handle = self.create_atomic_work("Undo this archive")
        self.repl.send("/archive " + handle + "\r")
        self.repl.wait("Archive this Work?")
        self.repl.send("y")
        self.repl.wait("Archived:")
        self.repl.send("\x1b")
        self.repl.wait("Undo the last recorded action?")
        self.repl.wait("Brick status changed")
        self.repl.send("n")
        self.repl.wait("Nothing was undone")
        self.assertIn("Status: archived", self.cli("show", handle)["details"])
        self.repl.send("\x1b")
        self.repl.await_exit("Escape at an archive receipt after declining undo")
        self.repl = Repl(self.executable, self.environment)
        self.repl.wait("mode:")
        self.repl.send("\x1b")
        with self.assertRaises(AssertionError):
            self.repl.wait("Undo the last recorded action?", timeout=1)
        self.repl.close()
        self.cli("restore", handle, "--yes")
        self.repl = Repl(self.executable, self.environment)
        self.repl.wait("mode:")
        self.repl.send("/archive " + handle + "\r")
        self.repl.wait("Archive this Work?")
        self.repl.send("y")
        self.repl.wait("Archived:")
        self.repl.send("\x1b")
        self.repl.wait("Undo the last recorded action?")
        self.repl.send("y")
        self.repl.wait("Undone:")
        self.assertIn("Status: active", self.cli("show", handle)["details"])
        self.repl.send("\x19")
        self.repl.wait("Redone:")
        self.assertIn("Status: archived", self.cli("show", handle)["details"])
        self.repl.send("\x1a")
        self.repl.wait("Undone:")
        self.assertIn("Status: active", self.cli("show", handle)["details"])
        self.repl.send("/redo")
        self.repl.wait("Redo the latest undone action")

    def test_archive_and_restore_are_discoverable_without_accepting_focus(self):
        handle = self.create_atomic_work("Move this work elsewhere")
        self.repl.send("/archive " + handle + "\r")
        self.repl.wait("Archive this Work?")
        self.repl.send("y")
        self.repl.wait("Archived:")
        self.assertIn("Status: archived", self.cli("show", handle)["details"])
        self.repl.send("/restore\r")
        self.repl.wait("Choose Work for /restore")
        self.repl.wait("Enter preview")
        self.repl.send("\r")
        self.repl.wait("Restore this Work?")
        self.repl.send("y")
        self.repl.wait("Restored:")
        self.assertIn("Status: active", self.cli("show", handle)["details"])
        events = [event for entry in self.cli("history", "100")["history"] for event in entry["event_types"]]
        self.assertFalse(any("focus" in event for event in events))

    def test_easier_work_shortlist_resumes_and_waits_for_focus_consent(self):
        source = self.create_atomic_work("Prepare the full proposal")
        self.create_atomic_work("Review the short summary", below=True)
        self.create_atomic_work("Draw one explanatory diagram", below=True)
        self.repl.close()
        self.cli("focus", source)
        self.repl = Repl(self.executable, self.environment, rows=32)
        self.repl.wait("Focus?")
        self.repl.send("s")
        self.repl.wait("[t]ired")
        self.repl.send("t")
        self.repl.wait("You're tired.")
        self.repl.send("e")
        self.repl.wait("Easier work:")
        self.repl.wait("Which of these feels easiest")
        dataset = self.root / "state/lant/profiles/default/dataset"
        checkpoint = dataset / "checkpoints/pending-envelope.json"
        saved = checkpoint.read_bytes()
        records = sorted(path.read_bytes() for path in dataset.rglob("*.jsonl"))
        self.repl.close()
        self.repl = Repl(self.executable, self.environment, rows=32)
        self.repl.wait("Easier work:")
        self.assertEqual(checkpoint.read_bytes(), saved)
        self.assertEqual(sorted(path.read_bytes() for path in dataset.rglob("*.jsonl")), records)
        self.repl.send("1")
        self.repl.wait("Focus?")
        self.assertIn("Work: idle", self.cli("show", source)["details"])
        events = [json.loads(line) for path in dataset.rglob("*.jsonl") for line in path.read_text().splitlines()]
        self.assertEqual(sum(event["event_type"] == "easier_work_offered" for event in events), 1)
        self.assertEqual(sum(event["event_type"] == "contextual_effort_recorded" for event in events), 1)
        self.assertFalse(any(event["event_type"] == "effort_classified" for event in events))
        self.assertTrue(self.cli("doctor")["healthy"])

    def test_done_advances_once_with_a_receipt_and_retains_the_next_focus_offer(self):
        baseline_environment = self.environment.copy()
        for gesture, columns in (("d", 80), ("/done\r", 28), (None, 80)):
            with self.subTest(gesture=gesture, columns=columns):
                with tempfile.TemporaryDirectory(prefix="done-case-", dir=self.root) as folder:
                    case_root = Path(folder)
                    self.environment = baseline_environment.copy()
                    self.environment.update({f"XDG_{name.upper()}_HOME": str(case_root / name) for name in ("config", "data", "state")})
                    self.environment["XDG_RUNTIME_DIR"] = str(case_root / "runtime")
                    first = self.create_atomic_work("Finish this first step")
                    second = self.create_atomic_work("Offer this second step", below=True)
                    self.repl.close()
                    self.cli("focus", first)
                    self.repl = Repl(self.executable, self.environment, columns=columns)
                    self.repl.wait("Focus?")
                    self.repl.send("y")
                    self.repl.wait("Current focus:")
                    dataset = case_root / "state/lant/profiles/default/dataset"
                    checkpoint = dataset / "checkpoints/pending-envelope.json"

                    def forecast_count():
                        return sum(json.loads(line)["event_type"] == "forecast_selected" for path in dataset.rglob("*.jsonl") for line in path.read_text().splitlines())

                    before_draws = forecast_count()
                    if gesture is None:
                        self.repl.close()
                        result = self.cli("done", first)
                        self.assertEqual(result["interaction"]["opportunity"]["type"], "completion_result")
                        self.assertEqual(forecast_count(), before_draws)
                        self.repl = Repl(self.executable, self.environment, columns=columns)
                    else:
                        self.repl.send(gesture)
                    self.repl.wait("✓ Completed:")
                    self.repl.wait("Focus?")
                    self.repl.wait("focus: idle")
                    self.assertIn(first, self.repl.terminal.text)
                    self.assertIn(second, self.repl.terminal.text)
                    self.assertEqual(forecast_count(), before_draws + 1)
                    after_checkpoint = checkpoint.read_bytes()
                    events = {str(path.relative_to(dataset)): path.read_bytes() for path in dataset.rglob("*.jsonl")}

                    # Resize is presentation maintenance, so it retains the receipt.
                    columns += 4
                    self.repl.terminal = Terminal(columns, 24)
                    fcntl.ioctl(self.repl.fd, termios.TIOCSWINSZ, struct.pack("HHHH", 24, columns, 0, 0))
                    os.kill(self.repl.pid, signal.SIGWINCH)
                    self.repl.wait("✓ Completed:")
                    self.repl.wait("Focus?")
                    self.repl.send("\x06")
                    self.repl.wait("Search")
                    self.assertNotIn("✓ Completed:", self.repl.terminal.text)
                    self.repl.send("\x1b")
                    self.repl.wait("Focus?")
                    self.assertNotIn("✓ Completed:", self.repl.terminal.text)
                    self.repl.send("/exit\r")
                    self.repl.await_exit("exit with the automatic next offer")
                    self.repl = Repl(self.executable, self.environment, columns=columns)
                    self.repl.wait("Focus?")
                    self.assertEqual(checkpoint.read_bytes(), after_checkpoint)
                    self.assertEqual({str(path.relative_to(dataset)): path.read_bytes() for path in dataset.rglob("*.jsonl")}, events)
                    self.assertIn("Work: idle", self.cli("show", second)["details"])
                    self.repl.close()

    def test_narrow_terminal_keeps_the_footer_and_search_reachable(self):
        self.launch(columns=28, rows=18)
        self.repl.wait("mode:")
        self.repl.send("\x06")
        self.repl.wait("Search")
        self.repl.wait("mode:")
        self.repl.send("\x1b")
        self.repl.wait("No Bricks yet.")

    def test_exit_gestures_preserve_the_pending_interaction(self):
        for gesture in ("q", "\x1b", "/quit\r", "/exit\r"):
            with self.subTest(gesture=repr(gesture)):
                self.launch()
                checkpoint = self.root / "state/lant/profiles/default/dataset/checkpoints/pending-envelope.json"
                before = checkpoint.read_bytes()
                self.repl.send(gesture)
                self.repl.await_exit(repr(gesture))
                self.assertEqual(checkpoint.read_bytes(), before)
                self.assertEqual(list(checkpoint.parent.parent.glob("events/*.jsonl")), [])

    def test_q_remains_text_in_editors_and_filters_and_nested_escape_returns(self):
        self.launch()
        self.repl.send("f")
        self.repl.wait("Feed Little Ant")
        self.repl.send("quiet draft")
        self.repl.wait("quiet draft")
        self.repl.send("\x06q\r")
        self.repl.wait("Search: q")
        self.repl.send("q")
        self.repl.wait("Filter: q")
        self.repl.send("\x1b")
        self.repl.wait("quiet draft")
        self.repl.send("\x1b")
        self.repl.wait("No Bricks yet.")

    def test_escape_returns_through_guided_navigation_before_exiting(self):
        self.launch()
        self.cli("feed", "Inspect exit navigation")
        self.repl.close()
        self.repl = Repl(self.executable, self.environment)
        self.repl.wait("Review raw material")
        self.repl.send("y")
        self.repl.wait("How should this behave?")
        self.repl.send("\x1b")
        self.repl.wait("Review raw material")
        self.repl.send("\x1b")
        self.repl.await_exit("Escape at the main Raw question")

    def test_escape_leaves_a_palette_command_screen_and_survives_a_replaced_question(self):
        handle = self.create_atomic_work("Leave the update hub")
        self.repl.send("/update " + handle + "\r")
        self.repl.wait("What changed?")
        self.repl.send("\x1b")
        self.repl.wait("Undo the last recorded action?")
        self.repl.send("n")
        self.repl.wait("Press Esc again to leave")
        self.repl.send("\x1b")
        self.repl.await_exit("Escape at the update hub opened from the palette")
        self.repl = Repl(self.executable, self.environment)
        self.repl.wait("mode:")
        self.repl.send("/update " + handle + "\r")
        self.repl.wait("What changed?")
        replacement = self.cli("focus", handle)
        self.repl.send("\x1b")
        self.repl.wait("This question changed outside this window")
        self.repl.wait("Focus?")
        self.assertNotIn("stale", self.repl.terminal.text)
        self.assertEqual(self.cli("interaction", "show")["interaction"], replacement["interaction"])
        self.repl.send("\x1b")
        self.repl.await_exit("Escape at the restored main question")

    def test_two_escapes_exit_the_palette_even_after_another_client_replaces_the_question(self):
        handle = self.create_atomic_work("Exit without changing another client")
        self.repl.close()
        self.cli("focus", handle)
        self.repl = Repl(self.executable, self.environment)
        self.repl.wait("Focus?")
        self.repl.send("/")
        self.repl.wait("More:")
        replacement = self.cli("focus", handle)
        checkpoint = self.root / "state/lant/profiles/default/dataset/checkpoints/pending-envelope.json"
        before = checkpoint.read_bytes()
        history = self.cli("history", "100")
        self.repl.send("\x1b")
        self.repl.wait("Focus?")
        self.repl.send("\x1b")
        self.repl.await_exit("Escape after closing the stale main-screen palette")
        self.assertEqual(checkpoint.read_bytes(), before)
        self.assertEqual(self.cli("history", "100"), history)
        self.assertEqual(self.cli("interaction", "show")["interaction"], replacement["interaction"])

    def test_long_title_palette_stays_compact_and_executes_the_original_target(self):
        handle = self.create_atomic_work("Bound the palette title")
        self.repl.close()
        title = "Avaliar a variante " + "界🙂 contexto " * 80 + "LAST_TITLE_WORD"
        self.cli("update", handle, "title", "--text", title, "--yes")
        for columns in (28, 160, 80):
            with self.subTest(columns=columns):
                self.cli("focus", handle)
                self.repl = Repl(self.executable, self.environment, columns=columns, rows=40)
                self.repl.wait("Work:")
                self.repl.send("/")
                self.repl.wait("More:")
                self.repl.wait("/done " + handle)
                self.repl.wait("(...)")
                self.assertNotIn("LAST_TITLE_WORD", self.repl.terminal.text)
                if columns != 80:
                    self.repl.close()
        self.repl.send("done\r")
        self.repl.wait("✓ Completed:")
        shown = self.cli("show", handle)
        self.assertEqual(shown["title"], title)
        self.assertIn("Status: done", shown["details"])

    def test_exit_and_restart_resume_the_same_focus_proposal_without_drawing(self):
        self.launch()
        self.cli("feed", "Keep this pending suggestion")
        self.repl.close()
        self.repl = Repl(self.executable, self.environment)
        self.repl.wait("Review raw material")
        self.repl.send("y")
        self.repl.wait("How should this behave?")
        self.repl.send("a")
        self.repl.wait("Where is it done?")
        self.repl.send("\r")
        self.repl.wait("a digital [t]ask")
        self.repl.send("\r")
        self.repl.wait("write Brick titles")
        self.repl.send("\r")
        self.repl.wait("Create this Work?")
        self.repl.send("y")
        self.repl.wait("Created:")
        self.repl.wait("Importance: only sibling")
        self.repl.send("n")
        self.repl.wait("Focus?")
        dataset = self.root / "state/lant/profiles/default/dataset"
        checkpoint = dataset / "checkpoints/pending-envelope.json"
        before_checkpoint = checkpoint.read_bytes()
        before_events = {path.name: path.read_bytes() for path in (dataset / "events").glob("*.jsonl")}
        self.repl.send("/why\r")
        self.repl.wait("Why this appeared:")
        self.repl.wait("Chance at selection:")
        self.repl.wait("[b] back")
        self.repl.send("d")
        self.repl.send("\x1b[F")
        self.repl.wait("Forecast profile:")
        self.repl.send("b")
        self.repl.wait("Focus?")
        self.assertEqual(checkpoint.read_bytes(), before_checkpoint)
        self.assertEqual({path.name: path.read_bytes() for path in (dataset / "events").glob("*.jsonl")}, before_events)
        explanation = self.cli("--view", "complete", "why")
        self.assertEqual(explanation["schema"], "little-ant/why@1")
        self.assertEqual(explanation["selection"]["explanation"]["opportunity_chance"], [1, 1])
        self.repl.send("/exit\r")
        self.repl.await_exit("/exit with a pending suggestion")
        self.repl = Repl(self.executable, self.environment)
        self.repl.wait("Focus?")
        self.assertEqual(checkpoint.read_bytes(), before_checkpoint)
        self.assertEqual({path.name: path.read_bytes() for path in (dataset / "events").glob("*.jsonl")}, before_events)

    def test_mouse_wheel_scrolls_documents_without_changing_the_pending_task(self):
        self.launch()
        material = "Mouse context\n\n" + "\n".join(f"- Evidence line {index}" for index in range(60)) + "\nMOUSE_END"
        self.cli("feed", material)
        for index in range(8):
            self.cli("feed", f"Mouse browser item {index}")
        self.repl.close()
        dataset = self.root / "state/lant/profiles/default/dataset"
        checkpoint = dataset / "checkpoints/pending-envelope.json"
        before = checkpoint.read_bytes()
        events = {path.name: path.read_bytes() for path in (dataset / "events").glob("*.jsonl")}
        handle = self.cli("search", "Mouse context")["hits"][0]["handle"]
        last_handle = self.cli("search", "Mouse")["hits"][-1]["handle"]
        for columns in (80, 28):
            with self.subTest(columns=columns):
                self.repl = Repl(self.executable, self.environment, columns=columns, rows=24)
                self.repl.wait("Review raw material")
                self.repl.send("/show " + handle + "\r")
                self.repl.wait("Original:")
                self.repl.wait("Rows 1–")
                bounds = re.search(r"Rows 1–(\d+)/(\d+)", self.repl.terminal.text)
                self.assertIsNotNone(bounds)
                visible, total = map(int, bounds.groups())
                self.repl.send("\x1b[<65;5;5M")
                self.repl.wait("Rows 4–")
                self.repl.send("\x1b[<64;5;5M")
                self.repl.wait("Rows 1–")
                self.repl.send("\x1b[F")
                bottom_start = total - visible + 1
                self.repl.wait(f"Rows {bottom_start}–")
                self.assertIn("MOUSE_END", self.repl.terminal.text)
                self.repl.send("\x1b[<64;5;5M")
                self.repl.wait(f"Rows {bottom_start - 3}–")
                self.repl.send("\x1b")
                self.repl.wait("Review raw material")
                self.repl.send("/search Mouse\r")
                self.repl.wait("Search: Mouse")
                self.repl.wait("Rows 1–")
                self.assertNotIn(last_handle, self.repl.terminal.text)
                self.repl.send("\x1b[<65;5;5M" * 8)
                self.repl.wait("> " + last_handle)
                self.repl.send("\x1b[<64;5;5M" * 8)
                self.repl.wait("Rows 1–")
                self.repl.send("\x1b")
                self.repl.wait("Review raw material")
                self.repl.close()
        self.assertEqual(checkpoint.read_bytes(), before)
        self.assertEqual({path.name: path.read_bytes() for path in (dataset / "events").glob("*.jsonl")}, events)

    def test_focus_uncertainty_opens_task_context_with_markdown_and_spacing(self):
        self.launch(columns=128, rows=40)
        material = "## Existing task context\n\nThis **important** explanation contains `state_raw_original` and enough ordinary prose to span several lines inside the comfortable reading width without depending on hard source wrapping.\n\n- Keep this list left aligned\n\n```text\n  value =  a +  b\n```"
        self.cli("feed", material)
        self.repl.close()
        self.repl = Repl(self.executable, self.environment, columns=128, rows=40)
        self.repl.wait("Review raw material")
        self.repl.send("y")
        self.repl.wait("How should this behave?")
        self.repl.send("a")
        self.repl.wait("Where is it done?")
        self.repl.send("\r")
        self.repl.wait("a digital [t]ask")
        self.repl.send("\r")
        self.repl.wait("write Brick titles")
        self.repl.send("Read Markdown\r")
        self.repl.wait("Create this Work?")
        self.repl.send("y")
        self.repl.wait("Created:")
        self.repl.send("n")
        self.repl.wait("Focus?")
        rows = ["".join(row).rstrip() for row in self.repl.terminal.grid]
        title_row = next(index for index, row in enumerate(rows) if '"Read Markdown"' in row)
        question_row = next(index for index, row in enumerate(rows) if "Focus?" in row)
        self.assertGreater(question_row, title_row + 1)
        dataset = self.root / "state/lant/profiles/default/dataset"
        events = {path.name: path.read_bytes() for path in (dataset / "events").glob("*.jsonl")}
        self.repl.send("k")
        self.repl.wait("Existing context:")
        self.repl.wait("value =  a +  b")
        text = self.repl.terminal.text
        self.assertIn("Existing task context", text)
        self.assertNotIn("## Existing task context", text)
        self.assertNotIn("**important**", text)
        self.assertNotIn("Would reviewing its existing context", text)
        self.assertIn("state_raw_original", text)
        self.assertEqual(text.count('"Read Markdown"'), 1)
        self.repl.wait("[d]ecide about focus")
        self.repl.wait("[b]ack to suggestion")
        self.repl.wait("I don't [k]now")
        self.repl.send("w")
        self.repl.wait("Why this appeared:")
        self.repl.wait("[t]ask context")
        self.repl.send("t")
        self.repl.wait("Existing context:")
        self.assertEqual(self.repl.terminal.text.count('"Read Markdown"'), 1)
        self.repl.send("d")
        self.repl.wait("Is it clear now what to do and where to start?")
        self.repl.send("y")
        self.repl.wait("Start focusing this Brick?")
        self.assertEqual({path.name: path.read_bytes() for path in (dataset / "events").glob("*.jsonl")}, events)
        self.repl.send("\x1b")
        self.repl.wait("Is it clear now what to do and where to start?")


if __name__ == "__main__":
    unittest.main()

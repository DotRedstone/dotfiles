#!/usr/bin/env python3
"""Scratch-only regression tests for the Codex queue path boundary."""

from __future__ import annotations

import importlib.util
import os
import tempfile
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).with_name("dsh-agent-runner.py")
SPEC = importlib.util.spec_from_file_location("dsh_agent_runner", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
RUNNER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RUNNER)


class QueueBoundaryTests(unittest.TestCase):
    def test_job_id_is_a_single_safe_component(self):
        for value in ("", "../escape", "/absolute", "a/b", "..", "a" * 81, None, 7):
            with self.subTest(value=value):
                self.assertFalse(isinstance(value, str) and RUNNER.ID_RE.fullmatch(value))
        for value in ("job-1", "codex_2026", "A"):
            with self.subTest(value=value):
                self.assertTrue(RUNNER.ID_RE.fullmatch(value))

    def test_open_dir_rejects_symlink_component(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            private = root / "private"
            private.mkdir()
            (root / "results").symlink_to(private, target_is_directory=True)
            root_fd = os.open(root, os.O_RDONLY | os.O_DIRECTORY)
            try:
                with self.assertRaises(OSError):
                    RUNNER.open_dir_at(root_fd, "results")
            finally:
                os.close(root_fd)

    def test_open_directory_fd_is_not_redirected_by_later_symlink_swap(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            results = root / "results"
            private = root / "private"
            results.mkdir()
            private.mkdir()
            results_fd = os.open(results, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
            moved = root / "results-held"
            results.rename(moved)
            results.symlink_to(private, target_is_directory=True)
            try:
                RUNNER.atomic_json_at(results_fd, "job-1.json", {
                    "jobId": "job-1", "status": "failed", "summary": "test",
                })
            finally:
                os.close(results_fd)
            self.assertTrue((moved / "job-1.json").is_file())
            self.assertFalse((private / "job-1.json").exists())


    def test_read_regular_rejects_fifo(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            fifo_path = root / "test.fifo"
            os.mkfifo(fifo_path)
            root_fd = os.open(root, os.O_RDONLY | os.O_DIRECTORY)
            try:
                with self.assertRaises(RUNNER.JobError) as ctx:
                    RUNNER.read_regular_at(root_fd, "test.fifo", 1024)
                self.assertIn("rejected FIFO/socket", str(ctx.exception))
            finally:
                os.close(root_fd)

    def test_cancellation_detection_and_consumption(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            cancel_dir = root / "cancel"
            cancel_dir.mkdir()
            cancel_fd = os.open(cancel_dir, os.O_RDONLY | os.O_DIRECTORY)
            try:
                job_id = "test-job-cancel-1"
                self.assertFalse(RUNNER.check_cancellation(cancel_fd, job_id))
                (cancel_dir / (job_id + ".cancel")).touch()
                self.assertTrue(RUNNER.check_cancellation(cancel_fd, job_id))
                RUNNER.consume_cancellation(cancel_fd, job_id)
                self.assertFalse(RUNNER.check_cancellation(cancel_fd, job_id))
            finally:
                os.close(cancel_fd)

    def test_recover_orphaned_claims(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            claimed = root / "claimed"
            results = root / "results"
            claimed.mkdir()
            results.mkdir()
            orphan = claimed / "claim-orphan-123.json"
            orphan.write_text('{"tool":"codex","prompt":"test","jobId":"orphan-job-1"}')
            # Set mtime to past
            old_time = time.time() - (RUNNER.TIMEOUT + 120)
            os.utime(orphan, (old_time, old_time))

            claimed_fd = os.open(claimed, os.O_RDONLY | os.O_DIRECTORY)
            results_fd = os.open(results, os.O_RDONLY | os.O_DIRECTORY)
            try:
                RUNNER.recover_orphaned_claims(claimed_fd, results_fd)
            finally:
                os.close(claimed_fd)
                os.close(results_fd)

            self.assertFalse(orphan.exists())
            result_file = results / "orphan-job-1.json"
            self.assertTrue(result_file.exists())
            data = json.loads(result_file.read_text())
            self.assertEqual(data["status"], "failed")
            self.assertIn("recovered orphaned task", data["summary"])


if __name__ == "__main__":
    import json
    import time
    unittest.main(verbosity=2)

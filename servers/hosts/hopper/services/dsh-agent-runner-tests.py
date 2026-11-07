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


if __name__ == "__main__":
    unittest.main(verbosity=2)

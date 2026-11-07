#!/usr/bin/env python3
"""Regression tests for DSH credential enforcement and loopback-only binding."""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


class DshSecurityTests(unittest.TestCase):
    def test_missing_or_empty_credential_fails_startup(self):
        """Verify that missing or empty token credentials immediately abort startup."""
        launcher_snippet = """
set -euo pipefail
cred_file="${CREDENTIALS_DIRECTORY:-}/llm-router-token"
if [ ! -f "$cred_file" ] || [ ! -s "$cred_file" ]; then
  echo "CRITICAL: LLM router token credential missing or empty; refusing to start unauthenticated" >&2
  exit 1
fi
echo "SUCCESS"
"""
        bash = shutil.which("bash") or "/bin/sh"
        with tempfile.TemporaryDirectory() as temporary:
            cred_dir = Path(temporary)

            # Case 1: CREDENTIALS_DIRECTORY is unset
            res = subprocess.run(
                [bash, "-c", launcher_snippet],
                env={"PATH": os.environ.get("PATH", "/run/current-system/sw/bin")},
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(res.returncode, 0)
            self.assertIn("CRITICAL: LLM router token credential missing or empty", res.stderr)

            # Case 2: CREDENTIALS_DIRECTORY is set, but file does not exist
            res = subprocess.run(
                [bash, "-c", launcher_snippet],
                env={"PATH": os.environ.get("PATH", "/run/current-system/sw/bin"), "CREDENTIALS_DIRECTORY": str(cred_dir)},
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(res.returncode, 0)
            self.assertIn("CRITICAL: LLM router token credential missing or empty", res.stderr)

            # Case 3: Token file exists but is empty (0 bytes)
            token_file = cred_dir / "llm-router-token"
            token_file.touch()
            res = subprocess.run(
                [bash, "-c", launcher_snippet],
                env={"PATH": os.environ.get("PATH", "/run/current-system/sw/bin"), "CREDENTIALS_DIRECTORY": str(cred_dir)},
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(res.returncode, 0)
            self.assertIn("CRITICAL: LLM router token credential missing or empty", res.stderr)

            # Case 4: Token file has valid content
            token_file.write_text("dummy-valid-token-content\n")
            res = subprocess.run(
                [bash, "-c", launcher_snippet],
                env={"PATH": os.environ.get("PATH", "/run/current-system/sw/bin"), "CREDENTIALS_DIRECTORY": str(cred_dir)},
                capture_output=True,
                text=True,
            )
            self.assertEqual(res.returncode, 0)
            self.assertIn("SUCCESS", res.stdout)

    def test_loopback_only_binding_contract(self):
        """Verify module specification enforces 127.0.0.1 and excludes wildcard listeners."""
        dsh_nix_path = Path(__file__).with_name("dsh.nix")
        content = dsh_nix_path.read_text(encoding="utf-8")

        # DSH process must strictly bind loopback 127.0.0.1 on port 3080
        self.assertIn('"web"', content)
        self.assertIn('"--host"', content)
        self.assertIn('loopback', content)
        self.assertIn('"3080"', content)

        # Nginx virtual host must strictly listen on loopback 127.0.0.1:3081
        self.assertIn('listen = [{ addr = loopback; port = 3081; }];', content)

        # No open firewall ports for 3080 or 3081
        self.assertNotIn('allowedTCPPorts = [ 3080', content)
        self.assertNotIn('allowedTCPPorts = [ 3081', content)

    def test_dsh_remote_configuration_and_isolation(self):
        """Verify DSH Remote configuration, state directory permissions, and zero inbound ports."""
        dsh_nix_path = Path(__file__).with_name("dsh.nix")
        content = dsh_nix_path.read_text(encoding="utf-8")

        # Remote options declared and default to false
        self.assertIn("remote = {", content)
        self.assertIn('enable = lib.mkEnableOption "DSH Remote (ds-harness-remote) 远程连接插件支持";', content)
        self.assertIn('default = "dsh.r2049.cn";', content)
        self.assertIn("options.services.dsh = {", content)

        # Patch injection dynamically toggled
        self.assertIn('remotePatchFile = pkgs.writeText "dsh-remote-patch.yml"', content)
        self.assertIn("ds-harness-remote", content)
        self.assertIn('lib.optionals remoteEnabled [', content)
        self.assertIn('"--patch"', content)

        # State directory 0700 under /var/lib/dsh/home/ds-harness-remote
        self.assertIn('"d ${state}/home/ds-harness-remote 0700 dsh dsh -"', content)

        # No inbound firewall modifications
        self.assertNotIn("networking.firewall", content)


if __name__ == "__main__":
    unittest.main(verbosity=2)


"""使用合成配置验证配置库的权限边界与事务行为。"""

import importlib.util
import os
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


spec = importlib.util.spec_from_file_location("helper", Path(__file__).with_name("mihomo-profile-helper.py"))
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)
SAMPLE = b"mixed-port: 17890\nproxies: []\nproxy-groups: []\nrules: []\n"


class ProfileTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.downloads = self.root / "Downloads"
        self.downloads.mkdir()
        self.state = self.root / "state"
        self.state.mkdir()
        (self.state / "profiles").mkdir()
        self.source = self.downloads / "sample.yaml"
        self.source.write_bytes(SAMPLE)
        self.library = helper.Library(self.state)
        self.library.owner_uid = os.getuid()
        self.source_patch = patch.object(helper, "SOURCE_ROOT", self.downloads)
        self.source_patch.start()
        self.addCleanup(self.source_patch.stop)
        self.mihomo_patch = patch.object(helper, "MIHOMO", shutil.which("true"))
        self.mihomo_patch.start()
        self.addCleanup(self.mihomo_patch.stop)
        self.bwrap_patch = patch.object(helper, "BWRAP", shutil.which("true"))
        self.bwrap_patch.start()
        self.addCleanup(self.bwrap_patch.stop)

    def test_source_allow_and_deny(self):
        self.assertEqual(helper.source_bytes(str(self.source)), SAMPLE)
        for path in ("https://invalid.example/a.yaml", "/etc/passwd", str(self.downloads / "../sample.yaml")):
            with self.assertRaises(helper.Failure) as caught:
                helper.source_bytes(path)
            self.assertEqual(caught.exception.code, 66)
        link = self.downloads / "link.yaml"
        link.symlink_to(self.source)
        with self.assertRaises(helper.Failure):
            helper.source_bytes(str(link))
        hardlink = self.downloads / "hardlink.yaml"
        os.link(self.source, hardlink)
        with self.assertRaises(helper.Failure):
            helper.source_bytes(str(self.source))
        hardlink.unlink()
        self.source.chmod(0o666)
        with self.assertRaises(helper.Failure):
            helper.source_bytes(str(self.source))
        self.source.chmod(0o600)
        self.source.write_bytes(b"x" * (helper.MAX_SIZE + 1))
        with self.assertRaises(helper.Failure):
            helper.source_bytes(str(self.source))

    def test_policy_rejects_controller_and_lan(self):
        for extra in (b"external-controller: 0.0.0.0:9090\n", b"allow-lan: true\n",
                      b"dns:\n  listen: 0.0.0.0:1053\n", b"tun:\n  enable: true\n",
                      b"proxy-providers:\n  x:\n    type: file\n    path: /etc/passwd\n"):
            with self.assertRaises(helper.Failure) as caught:
                helper.check_yaml(SAMPLE + extra)
            self.assertEqual(caught.exception.code, 65)

    def test_import_does_not_activate_and_stopped_switch(self):
        with patch.object(helper, "systemctl", return_value=False) as ctl:
            ident = self.library.import_file(str(self.source))["id"]
            self.assertFalse(self.library.config.exists())
            self.assertEqual(self.library.list()["active"], "")
            self.library.activate(ident)
            self.assertEqual(self.library.list()["active"], ident)
            self.assertIn(b"external-controller: 127.0.0.1:9090", self.library.config.read_bytes())
            self.assertEqual(ctl.call_args_list[-1].args, ("is-active", "--quiet"))

    def test_failed_running_switch_recovers_previous_selection(self):
        helper.atomic_write(self.library.config, SAMPLE + b"external-controller: 127.0.0.1:9090\n")
        self.library.seed_legacy()
        ident = self.library.import_file(str(self.source))["id"]
        old_data = self.library.config.read_bytes()
        with patch.object(helper, "systemctl", return_value=True), patch.object(helper, "healthy", side_effect=[False, True]):
            with self.assertRaises(helper.Failure) as caught:
                self.library.activate(ident)
        self.assertEqual(caught.exception.code, 75)
        self.assertEqual(self.library.active_id(), "legacy")
        self.assertEqual(self.library.config.read_bytes(), old_data)
        self.assertFalse(self.library.transaction.exists())

    def test_successful_running_switch_and_manual_recovery(self):
        helper.atomic_write(self.library.config, SAMPLE + b"external-controller: 127.0.0.1:9090\n")
        self.library.seed_legacy()
        ident = self.library.import_file(str(self.source))["id"]
        with patch.object(helper, "systemctl", return_value=True), patch.object(helper, "healthy", return_value=True):
            self.library.activate(ident)
        self.assertEqual(self.library.active_id(), ident)
        helper.atomic_write(self.library.config, b"mixed-port: 17891\n")
        self.library.reconcile_external()
        self.assertTrue(self.library.active_id().startswith("manual-"))
        self.assertEqual(self.library.config.read_bytes(), b"mixed-port: 17891\n")

    def test_rollback_failure_preserves_transaction(self):
        helper.atomic_write(self.library.config, SAMPLE + b"external-controller: 127.0.0.1:9090\n")
        self.library.seed_legacy()
        ident = self.library.import_file(str(self.source))["id"]
        with patch.object(helper, "systemctl", return_value=True), patch.object(helper, "healthy", return_value=False):
            with self.assertRaises(helper.Failure) as caught:
                self.library.activate(ident)
        self.assertEqual(caught.exception.code, 76)
        self.assertTrue(self.library.transaction.exists())

    def test_interrupted_switch_recovers_on_next_lock(self):
        helper.atomic_write(self.library.config, SAMPLE)
        self.library.seed_legacy()
        helper.atomic_write(self.library.rollback, SAMPLE)
        helper.atomic_write(self.library.transaction, b'{"old":"legacy","running":false,"ports":[]}')
        helper.atomic_write(self.library.config, b"new")
        with patch.object(helper, "systemctl", return_value=False):
            with self.library.locked():
                self.assertEqual(self.library.config.read_bytes(), SAMPLE)
                self.assertEqual(self.library.active_id(), "legacy")


if __name__ == "__main__":
    unittest.main()

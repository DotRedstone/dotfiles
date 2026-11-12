"""本机 Mihomo 配置库；仅由固定的 Polkit 入口以 root 身份调用。"""

import fcntl
import json
import os
import pwd
import re
import secrets
import shutil
import socket
import stat
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

import yaml


STATE = Path("/var/lib/mihomo")
SOURCE_ROOT = Path("/home/dot/Downloads")
SOURCE_UID = pwd.getpwnam("dot").pw_uid
MIHOMO = "@mihomo@"
BWRAP = "@bwrap@"
SYSTEMCTL = "@systemctl@"
MAX_SIZE = 2 * 1024 * 1024
ID_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]{0,63}\Z", re.ASCII)
PORT_KEYS = ("mixed-port", "port", "socks-port")
ALLOWED_KEYS = {
    "mode", "log-level", "ipv6", "unified-delay", "tcp-concurrent", "find-process-mode",
    "global-client-fingerprint", "geodata-mode", "geo-auto-update",
    "geo-update-interval", "profile", "proxy-providers", "proxies", "proxy-groups",
    "rule-providers", "rules", "dns", "sniffer", "hosts",
    "mixed-port", "port", "socks-port", "allow-lan", "bind-address",
    "keep-alive-interval", "keep-alive-idle",
}


class Failure(Exception):
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code


class UniqueLoader(yaml.SafeLoader):
    pass


def unique_mapping(loader, node):
    result = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=True)
        if not isinstance(key, str) or key in result:
            raise ValueError("重复或非字符串 YAML 键")
        result[key] = loader.construct_object(value_node, deep=True)
    return result


UniqueLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, unique_mapping)


def source_bytes(path):
    if not path.startswith(str(SOURCE_ROOT) + "/") or "\x00" in path:
        raise Failure(66, "来源不在允许的本地目录")
    parts = Path(path).parts
    if ".." in parts or "." in parts:
        raise Failure(66, "来源路径无效")
    fd = os.open("/", os.O_RDONLY | os.O_DIRECTORY)
    try:
        for index, part in enumerate(parts[1:], 1):
            last = index == len(parts) - 1
            flags = os.O_RDONLY | os.O_NOFOLLOW | (0 if last else os.O_DIRECTORY)
            next_fd = os.open(part, flags | os.O_NONBLOCK, dir_fd=fd)
            os.close(fd)
            fd = next_fd
            info = os.fstat(fd)
            if not last and not stat.S_ISDIR(info.st_mode):
                raise Failure(66, "来源路径不是目录")
        info = os.fstat(fd)
        if (not stat.S_ISREG(info.st_mode) or info.st_uid != SOURCE_UID or
                info.st_nlink != 1 or info.st_size == 0 or info.st_size > MAX_SIZE or
                info.st_mode & 0o022):
            raise Failure(66, "来源文件类型、所有者、权限或大小不符合要求")
        data = os.read(fd, MAX_SIZE + 1)
        if len(data) != info.st_size:
            raise Failure(66, "来源文件读取期间发生变化")
        return data
    except OSError as exc:
        raise Failure(66, "来源文件不可读取") from exc
    finally:
        os.close(fd)


def check_yaml(data, stored=False):
    try:
        config = yaml.load(data, Loader=UniqueLoader)
    except (yaml.YAMLError, ValueError, UnicodeError) as exc:
        raise Failure(65, "YAML 无效") from exc
    if not isinstance(config, dict):
        raise Failure(65, "配置不是 YAML 映射")
    if stored and config.get("external-controller") == "127.0.0.1:9090":
        config.pop("external-controller")
    if set(config) - ALLOWED_KEYS:
        raise Failure(65, "配置包含未授权的顶层选项")
    if config.get("allow-lan", False) is not False or config.get("bind-address", "127.0.0.1") not in ("127.0.0.1", "localhost"):
        raise Failure(65, "不允许局域网监听")
    dns = config.get("dns", {})
    dns_listen = dns.get("listen", "127.0.0.1:1053") if isinstance(dns, dict) else None
    if not isinstance(dns_listen, str) or dns_listen.split(":")[0] not in ("127.0.0.1", "localhost"):
        raise Failure(65, "DNS 仅允许本机监听")
    for kind in ("proxy-providers", "rule-providers"):
        providers = config.get(kind, {})
        if not isinstance(providers, dict):
            raise Failure(65, "provider 结构无效")
        for provider in providers.values():
            if not isinstance(provider, dict) or provider.get("type") != "http":
                raise Failure(65, "仅允许 HTTP provider")
            provider_path = provider.get("path", "")
            if provider_path and (not isinstance(provider_path, str) or
                                  Path(provider_path).is_absolute() or ".." in Path(provider_path).parts):
                raise Failure(65, "provider 路径无效")
    ports = []
    for key in PORT_KEYS:
        value = config.get(key)
        if value is not None:
            if type(value) is not int or not 1024 <= value <= 65535:
                raise Failure(65, "代理端口无效")
            ports.append(value)
    if not ports or len(ports) != len(set(ports)) or 9090 in ports:
        raise Failure(65, "需要独立的本机代理端口")
    if not isinstance(config.get("proxies", []), list) or not isinstance(config.get("proxy-groups", []), list):
        raise Failure(65, "代理结构无效")
    return ports


def atomic_write(path, data):
    temp = path.with_name(path.name + ".tmp-" + secrets.token_hex(8))
    fd = os.open(temp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp, path)
        sync_dir(path.parent)
    finally:
        temp.unlink(missing_ok=True)


def sync_dir(path):
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def systemctl(*args):
    return subprocess.run([SYSTEMCTL, "--system", "--no-ask-password", *args, "mihomo.service"],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=20).returncode == 0


def healthy(ports):
    deadline = time.monotonic() + 12
    while time.monotonic() < deadline:
        try:
            with urllib.request.urlopen("http://127.0.0.1:9090/version", timeout=1) as response:
                if response.status != 200:
                    raise OSError("controller unavailable")
            if ports:
                with socket.create_connection(("127.0.0.1", ports[0]), timeout=1):
                    pass
            return systemctl("is-active", "--quiet")
        except (OSError, TimeoutError):
            time.sleep(0.25)
    return False


class Library:
    def __init__(self, state=STATE):
        self.state = state
        self.owner_uid = 0
        self.profiles = state / "profiles"
        self.config = state / "config.yaml"
        self.active = state / "profile-active"
        self.transaction = state / "profile-transaction"
        self.rollback = state / "profile-rollback.yaml"

    def locked(self):
        if self.state.is_symlink() or (self.state.exists() and self.state.stat().st_uid != self.owner_uid):
            raise Failure(77, "状态目录不可信")
        self.state.mkdir(mode=0o700, parents=True, exist_ok=True)
        os.chmod(self.state, 0o700)
        self.profiles.mkdir(mode=0o700, exist_ok=True)
        if self.profiles.is_symlink() or self.profiles.stat().st_uid != self.owner_uid:
            raise Failure(77, "配置库目录不可信")
        os.chmod(self.profiles, 0o700)
        lock = open(self.state / "profile.lock", "a+b")
        os.chmod(self.state / "profile.lock", 0o600)
        fcntl.flock(lock, fcntl.LOCK_EX)
        self.recover()
        self.seed_legacy()
        self.reconcile_external()
        return lock

    def seed_legacy(self):
        if self.active.exists() or not self.config.is_file():
            return
        if self.config.is_symlink() or self.config.stat().st_uid != self.owner_uid:
            raise Failure(77, "既有配置不可信")
        data = self.config.read_bytes()
        if len(data) > MAX_SIZE + 256:
            raise Failure(65, "既有配置过大")
        atomic_write(self.profiles / "legacy.yaml", data)
        atomic_write(self.active, b"legacy\n")

    def active_id(self):
        value = self.active.read_text().strip() if self.active.exists() else ""
        if value and not ID_RE.fullmatch(value):
            raise Failure(77, "活动 ID 无效")
        return value

    def reconcile_external(self):
        if not self.config.exists() or not self.active.exists():
            return
        selected = self.profiles / (self.active_id() + ".yaml")
        if selected.exists() and selected.read_bytes() == self.config.read_bytes():
            return
        if self.config.is_symlink() or self.config.stat().st_uid != self.owner_uid:
            raise Failure(77, "活动配置不可信")
        data = self.config.read_bytes()
        if not data or len(data) > MAX_SIZE + 256 or len(self.entries()) >= 100:
            raise Failure(65, "手工配置无法登记")
        ident = "manual-" + secrets.token_hex(8)
        atomic_write(self.profiles / (ident + ".yaml"), data)
        atomic_write(self.active, (ident + "\n").encode())

    def entries(self):
        result = []
        for path in sorted(self.profiles.glob("*.yaml")):
            if path.is_symlink() or path.stat().st_uid != self.owner_uid:
                raise Failure(77, "配置库条目不可信")
            ident = path.stem
            if ID_RE.fullmatch(ident):
                name = "既有配置" if ident == "legacy" else ("手工恢复配置" if ident.startswith("manual-") else "配置 " + ident[2:10])
                result.append({"id": ident, "name": name})
        if len(result) > 100:
            raise Failure(65, "配置数量超过上限")
        return result

    def recover(self):
        if not self.transaction.exists():
            return
        record = json.loads(self.transaction.read_text())
        old_id = record["old"]
        if old_id and not ID_RE.fullmatch(old_id):
            raise Failure(76, "恢复记录无效")
        if self.rollback.exists():
            atomic_write(self.config, self.rollback.read_bytes())
        elif self.config.exists():
            self.config.unlink()
        if old_id:
            atomic_write(self.active, (old_id + "\n").encode())
        else:
            self.active.unlink(missing_ok=True)
        if record["running"] and (not systemctl("restart") or not healthy(record["ports"])):
            raise Failure(76, "恢复服务失败")
        self.transaction.unlink()
        self.rollback.unlink(missing_ok=True)
        sync_dir(self.state)

    def list(self):
        entries = self.entries()
        active = self.active_id()
        if active and active not in {item["id"] for item in entries}:
            raise Failure(77, "活动配置不存在")
        return {"profiles": entries, "active": active}

    def import_file(self, path):
        if len(self.entries()) >= 100:
            raise Failure(65, "配置数量达到上限")
        data = source_bytes(path)
        check_yaml(data)
        ident = "p-" + secrets.token_hex(12)
        staged = self.state / (ident + ".check.yaml")
        try:
            atomic_write(staged, data + b"\nexternal-controller: 127.0.0.1:9090\n")
            # 单独工作目录防止验证读取现有 provider 缓存；不记录配置正文或诊断输出。
            check_dir = self.state / (ident + ".check")
            check_dir.mkdir(mode=0o700)
            try:
                result = subprocess.run([
                    BWRAP, "--unshare-net", "--ro-bind", "/nix/store", "/nix/store",
                    "--dir", "/var", "--dir", "/var/lib", "--dir", str(self.state),
                    "--bind", str(check_dir), str(check_dir),
                    "--ro-bind", str(staged), str(staged),
                    "--dev", "/dev", "--proc", "/proc", "--tmpfs", "/tmp",
                    MIHOMO, "-t", "-d", str(check_dir), "-f", str(staged)],
                                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=15)
                if result.returncode:
                    raise Failure(65, "Mihomo 配置校验失败")
            finally:
                shutil.rmtree(check_dir)
            os.replace(staged, self.profiles / (ident + ".yaml"))
            sync_dir(self.profiles)
        finally:
            staged.unlink(missing_ok=True)
        return {"id": ident}

    def activate(self, ident):
        if not ID_RE.fullmatch(ident) or ident not in {item["id"] for item in self.entries()}:
            raise Failure(64, "配置 ID 无效")
        old = self.active_id()
        if old == ident:
            return {"id": ident}
        target = self.profiles / (ident + ".yaml")
        data = target.read_bytes()
        ports = check_yaml(data, stored=True) if ident != "legacy" and not ident.startswith("manual-") else []
        running = systemctl("is-active", "--quiet")
        old_ports = []
        if running and self.config.exists():
            try:
                old_config = yaml.load(self.config.read_bytes(), Loader=UniqueLoader)
                if isinstance(old_config, dict):
                    old_ports = [old_config[key] for key in PORT_KEYS if type(old_config.get(key)) is int]
            except (yaml.YAMLError, ValueError):
                pass
        if self.config.exists():
            atomic_write(self.rollback, self.config.read_bytes())
            backups = self.state / "backups"
            backups.mkdir(mode=0o700, exist_ok=True)
            backup = backups / ("config." + time.strftime("%Y%m%dT%H%M%SZ", time.gmtime()) + ".yaml")
            atomic_write(backup, self.config.read_bytes())
        atomic_write(self.transaction, json.dumps({"old": old, "running": running, "ports": old_ports}).encode())
        try:
            atomic_write(self.config, data)
            if running and (not systemctl("restart") or not healthy(ports)):
                raise Failure(75, "新配置未通过运行检查")
            atomic_write(self.active, (ident + "\n").encode())
            self.transaction.unlink()
            self.rollback.unlink(missing_ok=True)
            sync_dir(self.state)
            return {"id": ident}
        except Exception as exc:
            try:
                self.recover()
            except Exception as recovery_exc:
                raise Failure(76, "切换与回退均失败") from recovery_exc
            raise Failure(75, "切换失败，已恢复原配置") from exc


def main(argv):
    if os.geteuid() != 0:
        raise Failure(77, "需要受限授权")
    if len(argv) not in (1, 2) or argv[0] not in ("list", "import", "activate") or (argv[0] == "list") != (len(argv) == 1):
        raise Failure(64, "参数无效")
    library = Library()
    with library.locked():
        if argv[0] == "list":
            result = library.list()
        elif argv[0] == "import":
            result = library.import_file(argv[1])
        else:
            result = library.activate(argv[1])
    print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except Failure as error:
        print(str(error), file=sys.stderr)
        sys.exit(error.code)
    except (OSError, subprocess.TimeoutExpired):
        print("配置操作失败", file=sys.stderr)
        sys.exit(1)

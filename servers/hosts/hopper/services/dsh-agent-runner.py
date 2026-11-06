#!/usr/bin/env python3
"""Fixed, fail-closed dispatcher for Hopper's local coding-agent jobs."""

from __future__ import annotations

import argparse
import json
import os
import signal
import stat
import subprocess
import sys
import time
import uuid
from pathlib import Path

ROOT = Path("/var/lib/dsh/workspaces")
WORKSPACE = ROOT / "coding"
JOBS = ROOT / ".agent-jobs" / "codex"
STATE = Path("/var/lib/dsh-agent/jobs")
MAX_REQUEST = 64 * 1024
MAX_PROMPT = 48 * 1024
MAX_RESULT = 16 * 1024
TIMEOUT = 20 * 60
TOOL = "codex"


class JobError(Exception):
    pass


def regular_file(path: Path, *, max_size: int) -> bytes:
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_CLOEXEC", 0)
    fd = os.open(path, flags)
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_size > max_size:
            raise JobError("invalid request file")
        chunks = []
        remaining = max_size + 1
        while remaining:
            chunk = os.read(fd, min(65536, remaining))
            if not chunk:
                break
            chunks.append(chunk)
            remaining -= len(chunk)
        data = b"".join(chunks)
        if len(data) > max_size:
            raise JobError("request too large")
        return data
    finally:
        os.close(fd)


def atomic_json(path: Path, value: dict) -> None:
    encoded = json.dumps(value, ensure_ascii=True, separators=(",", ":")).encode()
    if len(encoded) > MAX_RESULT:
        encoded = json.dumps(
            {"jobId": value.get("jobId", ""), "status": "failed",
             "summary": "result exceeded size limit"},
            separators=(",", ":"),
        ).encode()
    temp = path.with_name("." + path.name + "." + uuid.uuid4().hex)
    fd = os.open(temp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o660)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(encoded)
            stream.write(b"\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp, path)
    finally:
        try:
            temp.unlink()
        except FileNotFoundError:
            pass


def self_test() -> int:
    checks = {}
    checks["workspace_writable"] = os.access(WORKSPACE, os.W_OK)
    checks["agent_home_private"] = STATE.parent.exists() and os.access(STATE.parent, os.W_OK)
    checks["secrets_hidden"] = not Path("/run/secrets").exists()
    checks["ssh_hidden"] = not Path("/etc/ssh").exists()
    checks["dsh_private_home_hidden"] = not Path("/var/lib/dsh/home").exists()
    checks["restic_hidden"] = not Path("/var/lib/restic").exists()
    checks["no_sudo"] = subprocess.run(
        ["/run/wrappers/bin/sudo", "-n", "true"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    ).returncode != 0
    # SocketBindDeny is verified by an explicit bind attempt inside this unit.
    import socket
    bind_blocked = False
    for family, address in (
        (socket.AF_INET, ("127.0.0.1", 0)),
        (socket.AF_INET6, ("::1", 0)),
    ):
        sock = socket.socket(family, socket.SOCK_STREAM)
        try:
            sock.bind(address)
        except OSError:
            bind_blocked = True
        else:
            bind_blocked = False
            break
        finally:
            sock.close()
    checks["socket_bind_denied"] = bind_blocked
    for key, passed in checks.items():
        print(f"{key}={'PASS' if passed else 'FAIL'}")
    return 0 if all(checks.values()) else 1


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--commands")
    parser.add_argument("--tool")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        return self_test()
    if args.tool != TOOL or not args.commands:
        raise JobError("unsupported tool")
    command_map = json.loads(Path(args.commands).read_text())
    executable = command_map.get(TOOL)
    if not isinstance(executable, str) or not executable.startswith("/nix/store/"):
        raise JobError("invalid fixed executable")

    request_path = JOBS / "request.json"
    if not request_path.exists():
        return 0
    STATE.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(STATE, 0o700)

    # Move the watched request out of the path unit's trigger location before
    # parsing it, so one request cannot cause an endless trigger loop.
    claimed = STATE / ("claimed-" + uuid.uuid4().hex + ".json")
    os.rename(request_path, claimed)
    job_id = "unknown"
    child = None
    try:
        raw = regular_file(claimed, max_size=MAX_REQUEST)
        request = json.loads(raw)
        if not isinstance(request, dict) or set(request) != {"tool", "prompt", "jobId"}:
            raise JobError("invalid request schema")
        if request["tool"] != TOOL:
            raise JobError("unsupported tool")
        prompt = request["prompt"]
        job_id = request["jobId"]
        if not isinstance(prompt, str) or not prompt.strip() or len(prompt.encode()) > MAX_PROMPT:
            raise JobError("invalid prompt")
        if not isinstance(job_id, str) or not job_id or len(job_id) > 80:
            raise JobError("invalid job id")
        if any(c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_" for c in job_id):
            raise JobError("invalid job id")
        done = STATE / (job_id + ".done")
        if done.exists():
            raise JobError("job id replay rejected")

        env = {
            "HOME": "/var/lib/dsh-agent",
            "CODEX_HOME": "/var/lib/dsh-agent/codex",
            "XDG_CONFIG_HOME": "/var/lib/dsh-agent/config",
            "XDG_DATA_HOME": "/var/lib/dsh-agent/data",
            "XDG_CACHE_HOME": "/var/lib/dsh-agent/cache",
            "PATH": os.environ.get("PATH", ""),
            "LANG": "C.UTF-8",
            "LC_ALL": "C.UTF-8",
            "TERM": "dumb",
            "NO_COLOR": "1",
            "SSL_CERT_FILE": os.environ.get("SSL_CERT_FILE", ""),
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": "/dev/null",
            "GIT_TERMINAL_PROMPT": "0",
            "GIT_CONFIG_COUNT": "1",
            "GIT_CONFIG_KEY_0": "credential.helper",
            "GIT_CONFIG_VALUE_0": "",
        }
        # The selected Codex release's CLI syntax must be confirmed against
        # its --help before enabling this runner on a live host. Never bypass
        # approvals or sandbox policy to make an incompatible release work.
        argv = [executable, "exec", "--json", "--sandbox", "workspace-write", "-"]
        log_path = STATE / (job_id + ".log")
        with open(log_path, "xb") as log:
            os.chmod(log_path, 0o600)
            child = subprocess.Popen(
                argv, cwd=WORKSPACE, env=env, stdin=subprocess.PIPE,
                stdout=log, stderr=subprocess.STDOUT, start_new_session=True,
            )
            try:
                child.communicate(prompt.encode(), timeout=TIMEOUT)
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGTERM)
                try:
                    child.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    os.killpg(child.pid, signal.SIGKILL)
                    child.wait()
                raise JobError("task timed out")
        status = "succeeded" if child.returncode == 0 else "failed"
        atomic_json(JOBS / "results" / (job_id + ".json"), {
            "jobId": job_id, "status": status, "exitCode": child.returncode,
            "summary": "Codex task finished; inspect the isolated workspace before use",
        })
        done.touch(mode=0o600, exist_ok=False)
        return 0 if child.returncode == 0 else child.returncode
    except Exception as exc:
        safe_message = str(exc).replace("\n", " ")[:240]
        try:
            atomic_json(JOBS / "results" / (job_id + ".json"), {
                "jobId": job_id, "status": "failed", "summary": safe_message,
            })
        except Exception:
            pass
        return 1
    finally:
        try:
            claimed.unlink()
        except FileNotFoundError:
            pass


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"runner failed: {str(error)[:200]}", file=sys.stderr)
        raise SystemExit(1)

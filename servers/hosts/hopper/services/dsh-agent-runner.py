#!/usr/bin/env python3
"""Fixed, fail-closed dispatcher for Hopper's local Codex jobs."""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import signal
import stat
import subprocess
import sys
import time
import uuid
from pathlib import Path

STATE = Path("/var/lib/dsh-agent/jobs")
MAX_REQUEST = 64 * 1024
MAX_PROMPT = 48 * 1024
MAX_RESULT = 16 * 1024
TIMEOUT = 18 * 60
TOOL = "codex"
ID_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9_-]{0,79}\Z")
DIR_FLAGS = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC
FILE_FLAGS = os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC | os.O_NONBLOCK
MIN_WORKSPACE_FREE_BYTES = 1024 * 1024 * 1024  # 1 GB


class JobError(Exception):
    pass


def open_dir_at(parent: int, name: str) -> int:
    fd = os.open(name, DIR_FLAGS, dir_fd=parent)
    info = os.fstat(fd)
    if not stat.S_ISDIR(info.st_mode) or info.st_mode & stat.S_IWOTH:
        os.close(fd)
        raise JobError("unsafe queue directory")
    return fd


def open_queue():
    """Walk from /var/lib/dsh using dirfds; never follow a mutable symlink."""
    root = os.open("/", DIR_FLAGS)
    var = open_dir_at(root, "var")
    lib = open_dir_at(var, "lib")
    dsh = open_dir_at(lib, "dsh")
    workspaces = open_dir_at(dsh, "workspaces")
    jobs_parent = open_dir_at(workspaces, ".agent-jobs")
    codex = open_dir_at(jobs_parent, "codex")
    claimed = open_dir_at(codex, "claimed")
    results = open_dir_at(codex, "results")
    cancel = open_dir_at(codex, "cancel")
    for fd in (root, var, lib, dsh, workspaces, jobs_parent):
        os.close(fd)
    return codex, claimed, results, cancel


def open_agent_state() -> int:
    fd = os.open(STATE.parent, DIR_FLAGS)
    info = os.fstat(fd)
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
        os.close(fd)
        raise JobError("agent state directory is not private")
    try:
        os.mkdir(STATE.name, 0o700, dir_fd=fd)
    except FileExistsError:
        pass
    jobs_fd = open_dir_at(fd, STATE.name)
    jobs_info = os.fstat(jobs_fd)
    if jobs_info.st_uid != os.getuid() or jobs_info.st_mode & 0o077:
        os.close(jobs_fd)
        os.close(fd)
        raise JobError("agent jobs directory is not private")
    os.close(fd)
    return jobs_fd


def read_regular_at(directory: int, name: str, max_size: int) -> bytes:
    fd = os.open(name, FILE_FLAGS, dir_fd=directory)
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or stat.S_ISFIFO(info.st_mode) or stat.S_ISSOCK(info.st_mode):
            raise JobError("invalid request file: must be a regular file, rejected FIFO/socket")
        if info.st_size > max_size:
            raise JobError("invalid request file: size exceeds limit")
        chunks = []
        remaining = max_size + 1
        while remaining:
            try:
                chunk = os.read(fd, min(65536, remaining))
            except BlockingIOError:
                break
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


def check_workspace_quota(workspace_path: str = "/var/lib/dsh/workspaces") -> None:
    try:
        usage = shutil.disk_usage(workspace_path)
        if usage.free < MIN_WORKSPACE_FREE_BYTES:
            raise JobError(f"workspace disk quota exceeded: only {usage.free // (1024 * 1024)}MB free")
    except (FileNotFoundError, OSError):
        pass


def check_cancellation(cancel_fd: int, job_id: str) -> bool:
    for name in (job_id + ".cancel", job_id):
        try:
            os.stat(name, dir_fd=cancel_fd, follow_symlinks=False)
            return True
        except FileNotFoundError:
            pass
    return False


def consume_cancellation(cancel_fd: int, job_id: str) -> None:
    for name in (job_id + ".cancel", job_id):
        try:
            os.unlink(name, dir_fd=cancel_fd)
        except FileNotFoundError:
            pass


def recover_orphaned_claims(claimed_fd: int, results_fd: int) -> None:
    """Detect and record failure for claims left behind after crash or restart."""
    try:
        now = time.time()
        for entry in os.scandir(f"/proc/self/fd/{claimed_fd}"):
            if not entry.name.startswith("claim-") or not entry.name.endswith(".json"):
                continue
            try:
                info = entry.stat(follow_symlinks=False)
                # Orphaned if older than TIMEOUT + 60s
                if now - info.st_mtime > (TIMEOUT + 60):
                    raw = read_regular_at(claimed_fd, entry.name, MAX_REQUEST)
                    data = json.loads(raw)
                    job_id = data.get("jobId")
                    if isinstance(job_id, str) and ID_RE.fullmatch(job_id):
                        atomic_json_at(results_fd, job_id + ".json", {
                            "jobId": job_id, "status": "failed",
                            "summary": "recovered orphaned task after crash/restart",
                        })
                    os.unlink(entry.name, dir_fd=claimed_fd)
            except Exception:
                pass
    except Exception:
        pass


def atomic_json_at(directory: int, name: str, value: dict) -> None:
    encoded = json.dumps(value, ensure_ascii=True, separators=(",", ":")).encode()
    if len(encoded) > MAX_RESULT:
        encoded = json.dumps(
            {"jobId": value.get("jobId", ""), "status": "failed",
             "summary": "result exceeded size limit"}, separators=(",", ":"),
        ).encode()
    temp = "." + uuid.uuid4().hex + ".tmp"
    fd = os.open(temp, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                 0o660, dir_fd=directory)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(encoded + b"\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.rename(temp, name, src_dir_fd=directory, dst_dir_fd=directory)
        os.fsync(directory)
    finally:
        try:
            os.unlink(temp, dir_fd=directory)
        except FileNotFoundError:
            pass


def self_test() -> int:
    checks = {}
    checks["workspace_writable"] = os.access("/var/lib/dsh/workspaces/coding", os.W_OK)
    checks["agent_home_private"] = os.access(STATE.parent, os.W_OK)
    checks["secrets_unavailable"] = not os.access("/run/secrets", os.R_OK | os.X_OK)
    checks["ssh_unavailable"] = not os.access("/etc/ssh", os.R_OK | os.X_OK)
    checks["dsh_home_unavailable"] = not os.access("/var/lib/dsh/home", os.R_OK | os.X_OK)
    checks["restic_unavailable"] = not os.access("/var/lib/restic", os.R_OK | os.X_OK)
    checks["etc_read_only"] = not os.access("/etc", os.W_OK)
    checks["sudo_denied"] = subprocess.run(
        ["/run/wrappers/bin/sudo", "-n", "true"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    ).returncode != 0
    import socket
    for label, family, address in (
        ("ipv4_bind_denied", socket.AF_INET, ("127.0.0.1", 0)),
        ("ipv6_bind_denied", socket.AF_INET6, ("::1", 0)),
    ):
        sock = socket.socket(family, socket.SOCK_STREAM)
        try:
            sock.bind(address)
        except PermissionError:
            checks[label] = True
        except OSError:
            checks[label] = False
        else:
            checks[label] = False
        finally:
            sock.close()
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

    codex_fd, claimed_fd, results_fd, cancel_fd = open_queue()
    state_fd = open_agent_state()
    recover_orphaned_claims(claimed_fd, results_fd)

    claim_name = "claim-" + uuid.uuid4().hex + ".json"
    child = None
    validated_job_id = None
    claimed = False
    try:
        try:
            os.rename("request.json", claim_name,
                      src_dir_fd=codex_fd, dst_dir_fd=claimed_fd)
            claimed = True
        except FileNotFoundError:
            return 0
        raw = read_regular_at(claimed_fd, claim_name, MAX_REQUEST)
        request = json.loads(raw)
        if not isinstance(request, dict) or set(request) != {"tool", "prompt", "jobId"}:
            raise JobError("invalid request schema")
        if request["tool"] != TOOL:
            raise JobError("unsupported tool")
        prompt = request["prompt"]
        candidate = request["jobId"]
        if not isinstance(prompt, str) or not prompt.strip() or len(prompt.encode()) > MAX_PROMPT:
            raise JobError("invalid prompt")
        if not isinstance(candidate, str) or not ID_RE.fullmatch(candidate):
            raise JobError("invalid job id")
        validated_job_id = candidate

        if check_cancellation(cancel_fd, validated_job_id):
            consume_cancellation(cancel_fd, validated_job_id)
            atomic_json_at(results_fd, validated_job_id + ".json", {
                "jobId": validated_job_id, "status": "cancelled",
                "summary": "task cancelled before start",
            })
            return 1

        check_workspace_quota()

        done_name = validated_job_id + ".done"
        try:
            os.stat(done_name, dir_fd=state_fd, follow_symlinks=False)
        except FileNotFoundError:
            pass
        else:
            raise JobError("job id replay rejected")

        env = {
            "HOME": "/var/lib/dsh-agent",
            "CODEX_HOME": "/var/lib/dsh-agent/codex",
            "XDG_CONFIG_HOME": "/var/lib/dsh-agent/config",
            "XDG_DATA_HOME": "/var/lib/dsh-agent/data",
            "XDG_CACHE_HOME": "/var/lib/dsh-agent/cache",
            "PATH": os.environ.get("PATH", ""),
            "LANG": "C.UTF-8", "LC_ALL": "C.UTF-8", "TERM": "dumb", "NO_COLOR": "1",
            "SSL_CERT_FILE": os.environ.get("SSL_CERT_FILE", ""),
            "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": "/dev/null",
            "GIT_TERMINAL_PROMPT": "0", "GIT_CONFIG_COUNT": "1",
            "GIT_CONFIG_KEY_0": "credential.helper", "GIT_CONFIG_VALUE_0": "",
        }
        argv = [executable, "exec", "--json", "--sandbox", "workspace-write", "-"]
        log_name = validated_job_id + ".log"
        log_fd = os.open(log_name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                         0o600, dir_fd=state_fd)
        with os.fdopen(log_fd, "wb") as log:
            child = subprocess.Popen(
                argv, cwd="/var/lib/dsh/workspaces/coding", env=env,
                stdin=subprocess.PIPE, stdout=log, stderr=subprocess.STDOUT,
                start_new_session=True,
            )
            try:
                child.stdin.write(prompt.encode())
                child.stdin.close()
            except Exception:
                pass

            cancelled = False
            start_time = time.monotonic()
            while True:
                if check_cancellation(cancel_fd, validated_job_id):
                    cancelled = True
                    break
                ret = child.poll()
                if ret is not None:
                    break
                if time.monotonic() - start_time > TIMEOUT:
                    os.killpg(child.pid, signal.SIGTERM)
                    try:
                        child.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        os.killpg(child.pid, signal.SIGKILL)
                        child.wait()
                    atomic_json_at(results_fd, validated_job_id + ".json", {
                        "jobId": validated_job_id, "status": "timed_out",
                        "summary": f"task timed out after {TIMEOUT}s",
                    })
                    return 1
                time.sleep(0.5)

            if cancelled:
                os.killpg(child.pid, signal.SIGTERM)
                try:
                    child.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(child.pid, signal.SIGKILL)
                    child.wait()
                consume_cancellation(cancel_fd, validated_job_id)
                atomic_json_at(results_fd, validated_job_id + ".json", {
                    "jobId": validated_job_id, "status": "cancelled",
                    "summary": "task cancelled by user request",
                })
                return 1

        status = "succeeded" if child.returncode == 0 else "failed"
        atomic_json_at(results_fd, validated_job_id + ".json", {
            "jobId": validated_job_id, "status": status,
            "exitCode": child.returncode,
            "summary": "Codex task finished; inspect the isolated workspace before use",
        })
        done_fd = os.open(done_name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                          0o600, dir_fd=state_fd)
        os.close(done_fd)
        return 0 if child.returncode == 0 else child.returncode
    except Exception as exc:
        safe_message = str(exc).replace("\n", " ")[:240]
        result_id = validated_job_id or ("rejected-" + uuid.uuid4().hex)
        try:
            atomic_json_at(results_fd, result_id + ".json", {
                "jobId": validated_job_id or "", "status": "failed", "summary": safe_message,
            })
        except Exception:
            pass
        return 1
    finally:
        if claimed:
            try:
                os.unlink(claim_name, dir_fd=claimed_fd)
            except FileNotFoundError:
                pass
        for fd in (codex_fd, claimed_fd, results_fd, cancel_fd, state_fd):
            os.close(fd)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"runner failed: {str(error)[:200]}", file=sys.stderr)
        raise SystemExit(1)

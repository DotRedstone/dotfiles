#!/usr/bin/env python3
"""Transactional DSH quiesce/restore coordinator for hopper-local backups."""

from __future__ import annotations

import fcntl
import json
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import uuid
from contextlib import contextmanager
from pathlib import Path

SYSTEMCTL = shutil.which("systemctl") or "/run/current-system/sw/bin/systemctl"
TAR = shutil.which("tar") or "/run/current-system/sw/bin/tar"
STATE_DIR = Path("/run/dsh-backup-session")
STATE_FILE = STATE_DIR / "state.json"
LOCK_FILE = STATE_DIR / "lock"
DSH_GATE = STATE_DIR / "dsh-paused"
AGENT_GATE = STATE_DIR / "agents-paused"
STAGING = Path("/var/lib/restic/staging/dsh")
ARCHIVE = STAGING / "dsh.tar"
DSH_UNIT = "dsh.service"
PATH_UNITS = ("dsh-coding-codex.path",)
TASK_UNITS = ("dsh-coding@codex.service", "dsh-coding-self-test.service")
UNITS = (DSH_UNIT, *PATH_UNITS, *TASK_UNITS)
ACTIVE_STATES = {"active", "activating", "reloading"}
STOPPED_STATES = {"inactive", "failed"}


class SessionError(RuntimeError):
    pass


@contextmanager
def transaction_lock():
    STATE_DIR.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(STATE_DIR, 0o700)
    fd = os.open(LOCK_FILE, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX)
        yield
    finally:
        fcntl.flock(fd, fcntl.LOCK_UN)
        os.close(fd)


def systemctl(*args: str, check: bool = True) -> str:
    result = subprocess.run(
        [SYSTEMCTL, *args], text=True, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, check=False,
    )
    if check and result.returncode:
        raise SessionError(f"systemctl {' '.join(args)} failed ({result.returncode})")
    return result.stdout.strip()


def show(unit: str, prop: str) -> str:
    try:
        return systemctl("show", "--property=" + prop, "--value", unit, check=False)
    except OSError:
        return ""


def inspect_unit(unit: str) -> dict:
    load = show(unit, "LoadState")
    if load in {"", "not-found"}:
        return {"present": False, "restore": False, "active_before": "not-found",
                "freeze_pending": False, "frozen": False, "task_lost": False}
    active = show(unit, "ActiveState")
    return {"present": True, "restore": active in ACTIVE_STATES,
            "active_before": active, "freeze_pending": False,
            "frozen": False, "task_lost": False}


def save_state(state: dict) -> None:
    STATE_DIR.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(STATE_DIR, 0o700)
    fd, temporary = tempfile.mkstemp(prefix=".state.", dir=STATE_DIR)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(state, stream, sort_keys=True)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, STATE_FILE)
        directory_fd = os.open(STATE_DIR, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    finally:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass


def load_state() -> dict:
    try:
        state = json.loads(STATE_FILE.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return {}
    except (OSError, json.JSONDecodeError) as error:
        raise SessionError("backup recovery state is unreadable") from error
    if (not isinstance(state, dict) or state.get("schema") != 2
            or not isinstance(state.get("units"), dict)
            or set(state["units"]) != set(UNITS)):
        raise SessionError("backup recovery state has an invalid schema")
    return state


def wait_for(unit: str, predicate, timeout: int, description: str) -> dict:
    deadline = time.monotonic() + timeout
    last = {}
    while time.monotonic() < deadline:
        last = {"active": show(unit, "ActiveState"),
                "main_pid": show(unit, "MainPID"),
                "control_pid": show(unit, "ControlPID"),
                "freezer": show(unit, "FreezerState")}
        if predicate(last):
            return last
        time.sleep(0.25)
    raise SessionError(f"{unit} did not reach {description} within {timeout}s")


def create_gate(path: Path, state: dict, key: str) -> None:
    state[key] = "pending"
    save_state(state)
    fd, temporary = tempfile.mkstemp(prefix=".gate.", dir=STATE_DIR)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="ascii") as stream:
            stream.write(state["session"] + "\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        state[key] = "owned"
        save_state(state)
    finally:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass


def remove_gate(path: Path, state: dict, key: str, failures: list[str]) -> None:
    if state.get(key) not in {"pending", "owned"}:
        return
    try:
        try:
            fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC)
        except FileNotFoundError:
            fd = -1
        if fd >= 0:
            try:
                token = os.read(fd, 128).decode("ascii").strip()
            finally:
                os.close(fd)
            if token != state["session"]:
                raise SessionError(f"refusing to remove a gate not owned by session {state['session']}")
            path.unlink()
        state[key] = "removed"
        save_state(state)
    except Exception as error:
        failures.append(f"remove {path.name}: {error}")


def stop_and_confirm(unit: str, timeout: int) -> None:
    if show(unit, "ActiveState") not in STOPPED_STATES:
        systemctl("stop", unit)
    wait_for(unit, lambda v: v["active"] in STOPPED_STATES
             and v["main_pid"] in {"", "0"}
             and v["control_pid"] in {"", "0"}, timeout,
             "fully stopped with no main/control process")


def freeze_task(unit: str, record: dict, state: dict) -> None:
    if not record["present"]:
        return
    active = show(unit, "ActiveState")
    if active in STOPPED_STATES:
        record["restore"] = False
        save_state(state)
        return
    pid = show(unit, "MainPID")
    if not record["restore"] or pid in {"", "0"}:
        stop_and_confirm(unit, 40)
        record["restore"] = False
        save_state(state)
        return
    record["freeze_pending"] = True
    save_state(state)
    systemctl("freeze", unit)
    wait_for(unit, lambda v: v["freezer"] == "frozen", 20, "frozen")
    record["frozen"] = True
    record["freeze_pending"] = False
    save_state(state)


def wait_for_dsh_listener(timeout: int = 60) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            with socket.create_connection(("127.0.0.1", 3080), timeout=1):
                return
        except OSError:
            time.sleep(0.5)
    raise SessionError("DSH listener 127.0.0.1:3080 did not become ready")


def prepare_locked() -> None:
    if STATE_FILE.exists():
        raise SessionError("an earlier backup session still needs recovery; run resume first")
    if DSH_GATE.exists() or AGENT_GATE.exists():
        raise SessionError("a backup gate exists without its state file; manual recovery required")
    state = {
        "schema": 2, "session": uuid.uuid4().hex,
        "units": {unit: inspect_unit(unit) for unit in UNITS},
        "dsh_gate": "absent", "agent_gate": "absent",
        "archive_ready": False, "errors": [], "warnings": [],
    }
    save_state(state)
    try:
        # NixOS unit conditions are the gate; runtime masks cannot override /etc units.
        create_gate(DSH_GATE, state, "dsh_gate")
        create_gate(AGENT_GATE, state, "agent_gate")
        for unit in PATH_UNITS:
            if state["units"][unit]["present"]:
                stop_and_confirm(unit, 40)
        for unit in TASK_UNITS:
            freeze_task(unit, state["units"][unit], state)
        if state["units"][DSH_UNIT]["present"]:
            stop_and_confirm(DSH_UNIT, 180)

        STAGING.mkdir(mode=0o700, parents=True, exist_ok=True)
        os.chmod(STAGING, 0o700)
        temporary = STAGING / ("dsh-" + state["session"] + ".tar.tmp")
        previous_umask = os.umask(0o077)
        try:
            subprocess.run([TAR, "--no-xattrs",
                            "--exclude=dsh/workspaces/.agent-jobs",
                            "--exclude=dsh/workspaces/.agent-auth",
                            "-C", "/var/lib", "-cpf", str(temporary), "dsh"],
                           check=True)
        finally:
            os.umask(previous_umask)
        os.replace(temporary, ARCHIVE)
        state["archive_ready"] = True
        save_state(state)
        directory_fd = os.open(STAGING, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    except Exception as error:
        try:
            resume_locked()
        except Exception as recovery_error:
            raise SessionError(
                f"prepare failed ({error}); recovery failed ({recovery_error}); state retained"
            ) from recovery_error
        raise


def resume_locked() -> None:
    state = load_state()
    if not state:
        if DSH_GATE.exists() or AGENT_GATE.exists():
            raise SessionError("backup gate exists without a recovery state file")
        return
    failures: list[str] = []
    records = state["units"]

    # Release only the DSH gate before attempting DSH startup.
    remove_gate(DSH_GATE, state, "dsh_gate", failures)
    dsh = records[DSH_UNIT]
    if dsh.get("present") and dsh.get("restore") and not state.get("dsh_restored"):
        try:
            systemctl("start", DSH_UNIT)
            wait_for(DSH_UNIT, lambda v: v["active"] == "active"
                     and v["main_pid"] not in {"", "0"}, 40,
                     "active with executed main process")
            wait_for_dsh_listener()
            state["dsh_restored"] = True
            save_state(state)
        except Exception as error:
            failures.append(f"restore {DSH_UNIT}: {error}")

    # DSH startup failure must not block independent task thaw attempts.
    for unit in TASK_UNITS:
        record = records[unit]
        if not record.get("present") or not record.get("restore"):
            continue
        if not (record.get("freeze_pending") or record.get("frozen")):
            continue
        try:
            active = show(unit, "ActiveState")
            if active in STOPPED_STATES:
                record["task_lost"] = True
                record["freeze_pending"] = False
                record["frozen"] = False
                record["restore"] = False
                state["warnings"].append(
                    f"{unit} exited while frozen; it was not restarted; inspect its claimed job/log"
                )
                save_state(state)
                continue
            freezer = show(unit, "FreezerState")
            if freezer == "freezing":
                wait_for(unit, lambda v: v["freezer"] == "frozen", 20, "frozen before thaw")
                freezer = "frozen"
            if freezer in {"frozen", "thawing"}:
                systemctl("thaw", unit)
                wait_for(unit, lambda v: v["freezer"] in {"running", "thawed"},
                         20, "running after thaw")
            elif freezer not in {"running", "thawed"}:
                raise SessionError(f"unrecognized freezer state {freezer!r}")
            record["freeze_pending"] = False
            record["frozen"] = False
            save_state(state)
        except Exception as error:
            failures.append(f"thaw {unit}: {error}")

    # The snapshot is complete; release the task gate and restore the watcher.
    remove_gate(AGENT_GATE, state, "agent_gate", failures)
    for unit in PATH_UNITS:
        record = records[unit]
        if record.get("present") and record.get("restore") and not state.get("watcher_restored"):
            try:
                systemctl("start", unit)
                wait_for(unit, lambda v: v["active"] == "active", 20, "active path watcher")
                state["watcher_restored"] = True
                save_state(state)
            except Exception as error:
                failures.append(f"restore {unit}: {error}")

    if show("restic-backups-hopper-local.service", "Result") == "success":
        try:
            ARCHIVE.unlink(missing_ok=True)
        except Exception as error:
            failures.append(f"remove completed archive: {error}")

    state["errors"] = failures
    save_state(state)
    pending = (
        (dsh.get("present") and dsh.get("restore") and not state.get("dsh_restored"))
        or any(r.get("freeze_pending") or r.get("frozen") for r in records.values())
        or (any(records[u].get("restore") for u in PATH_UNITS)
            and not state.get("watcher_restored"))
        or state.get("dsh_gate") in {"pending", "owned"}
        or state.get("agent_gate") in {"pending", "owned"}
    )
    if failures or pending:
        raise SessionError("recovery incomplete; state retained: " + "; ".join(failures)[:600])
    for warning in state.get("warnings", []):
        print("dsh-backup-session warning: " + warning, file=sys.stderr)
    STATE_FILE.unlink()
    directory_fd = os.open(STATE_DIR, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        os.fsync(directory_fd)
    finally:
        os.close(directory_fd)


def prepare() -> None:
    with transaction_lock():
        prepare_locked()


def resume() -> None:
    with transaction_lock():
        resume_locked()


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] not in {"prepare", "resume"}:
        raise SessionError("expected prepare or resume")
    if sys.argv[1] == "prepare":
        prepare()
    else:
        resume()
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"dsh-backup-session: {str(error)[:500]}", file=sys.stderr)
        raise SystemExit(1)

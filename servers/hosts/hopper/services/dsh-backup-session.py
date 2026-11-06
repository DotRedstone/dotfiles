#!/usr/bin/env python3
"""Pause Hopper DSH and coding-agent writers for hopper-local snapshots."""

from __future__ import annotations

import json
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path

SYSTEMCTL = shutil.which("systemctl") or "/run/current-system/sw/bin/systemctl"
TAR = shutil.which("tar") or "/run/current-system/sw/bin/tar"
STATE_DIR = Path("/run/dsh-backup-session")
STATE_FILE = STATE_DIR / "state.json"
STAGING = Path("/var/lib/restic/staging/dsh")
ARCHIVE = STAGING / "dsh.tar"
PREPARE_UNIT = "dsh-backup-prepare.service"
DSH_UNIT = "dsh.service"
PATH_UNITS = ("dsh-coding-codex.path",)
TASK_UNITS = ("dsh-coding@codex.service", "dsh-coding-self-test.service")
UNITS = (DSH_UNIT, *PATH_UNITS, "dsh-coding@.service", *TASK_UNITS)
RESTORE_STATES = {"active", "activating", "reloading", "auto-restart"}
STOPPED_STATES = {"inactive", "failed"}


class SessionError(RuntimeError):
    pass


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
        return {"present": False, "masked_before": False, "masked_by_us": False,
                "restore": False, "active_before": "not-found",
                "freeze_pending": False, "frozen": False}
    file_state = show(unit, "UnitFileState")
    masked = load == "masked" or file_state in {"masked", "masked-runtime"}
    active = show(unit, "ActiveState")
    return {"present": True, "masked_before": masked, "masked_by_us": False,
            "restore": not masked and active in RESTORE_STATES,
            "active_before": active, "freeze_pending": False, "frozen": False}


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
        directory_fd = os.open(STATE_DIR, os.O_RDONLY)
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
    if (not isinstance(state, dict) or state.get("schema") != 1
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


def mask_unit(unit: str, record: dict, state: dict) -> None:
    if not record["present"] or record["masked_before"]:
        return
    record["masked_by_us"] = True
    save_state(state)  # Persist before masking so interrupted recovery can unmask.
    systemctl("mask", "--runtime", unit)


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
    if record["restore"] and active in RESTORE_STATES and pid not in {"", "0"}:
        record["freeze_pending"] = True
        save_state(state)  # Recovery thaws even if this process dies after freeze.
        systemctl("freeze", unit)
        wait_for(unit, lambda v: v["freezer"] == "frozen", 20, "frozen")
        record["frozen"] = True
        record["freeze_pending"] = False
        save_state(state)
    else:
        # Cancel a queued activation; the request file remains for the watcher.
        stop_and_confirm(unit, 40)
        record["restore"] = False
        save_state(state)


def wait_for_dsh_listener(timeout: int = 60) -> None:
    deadline = time.monotonic() + timeout
    last_error = "not yet accepting connections"
    while time.monotonic() < deadline:
        try:
            with socket.create_connection(("127.0.0.1", 3080), timeout=1):
                return
        except OSError as error:
            last_error = error.__class__.__name__
            time.sleep(0.5)
    raise SessionError(f"DSH listener 127.0.0.1:3080 not ready: {last_error}")


def prepare() -> None:
    if STATE_FILE.exists():
        resume()  # Never discard a marker from an earlier failed recovery.
    state = {"schema": 1, "units": {unit: inspect_unit(unit) for unit in UNITS}}
    save_state(state)
    try:
        for unit in UNITS:
            mask_unit(unit, state["units"][unit], state)
        for unit in PATH_UNITS:
            if state["units"][unit]["present"]:
                stop_and_confirm(unit, 40)
        for unit in TASK_UNITS:
            freeze_task(unit, state["units"][unit], state)
        if state["units"][DSH_UNIT]["present"]:
            # Stops active, activating and auto-restart alike; cancels pending restart.
            stop_and_confirm(DSH_UNIT, 180)

        STAGING.mkdir(mode=0o700, parents=True, exist_ok=True)
        os.chmod(STAGING, 0o700)
        temporary = STAGING / "dsh.tar.tmp"
        temporary.unlink(missing_ok=True)
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
        directory_fd = os.open(STAGING, os.O_RDONLY)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    except Exception as error:
        try:
            resume()
        except Exception as recovery_error:
            raise SessionError(f"prepare failed ({error}); recovery failed ({recovery_error}); marker retained") from recovery_error
        raise


def stop_prepare_unit() -> None:
    if show(PREPARE_UNIT, "LoadState") not in {"", "not-found"}:
        stop_and_confirm(PREPARE_UNIT, 30)


def resume(*, stop_prepare: bool = False) -> None:
    if stop_prepare:
        stop_prepare_unit()
    state = load_state()
    if not state:
        return
    records = state["units"]

    for unit in UNITS:
        if records[unit].get("masked_by_us"):
            systemctl("unmask", "--runtime", unit)

    dsh = records[DSH_UNIT]
    if dsh.get("present") and dsh.get("restore"):
        systemctl("start", DSH_UNIT)
        wait_for(DSH_UNIT, lambda v: v["active"] == "active" and v["main_pid"] not in {"", "0"},
                 40, "active with executed main process")
        wait_for_dsh_listener()

    for unit in TASK_UNITS:
        record = records[unit]
        if not record.get("present") or not record.get("restore"):
            continue
        if not (record.get("freeze_pending") or record.get("frozen")):
            continue
        if show(unit, "ActiveState") in STOPPED_STATES:
            raise SessionError(f"previously running task {unit} is no longer active")
        freezer = show(unit, "FreezerState")
        if freezer == "freezing":
            wait_for(unit, lambda v: v["freezer"] == "frozen", 20, "frozen before thaw")
            freezer = "frozen"
        if freezer in {"frozen", "thawing"}:
            systemctl("thaw", unit)
            wait_for(unit, lambda v: v["freezer"] in {"running", "thawed"},
                     20, "running after thaw")
        elif freezer not in {"running", "thawed"}:
            raise SessionError(f"cannot verify freezer state for {unit}")

    for unit in PATH_UNITS:
        record = records[unit]
        if record.get("present") and record.get("restore"):
            systemctl("start", unit)
            wait_for(unit, lambda v: v["active"] == "active", 20, "active path watcher")

    if show("restic-backups-hopper-local.service", "Result") == "success":
        ARCHIVE.unlink(missing_ok=True)
    STATE_FILE.unlink()  # Only after every required restore action succeeded.
    directory_fd = os.open(STATE_DIR, os.O_RDONLY)
    try:
        os.fsync(directory_fd)
    finally:
        os.close(directory_fd)


def main() -> int:
    if len(sys.argv) not in {2, 3}:
        raise SessionError("expected prepare or resume [--stop-prepare]")
    if sys.argv[1] == "prepare" and len(sys.argv) == 2:
        prepare()
    elif sys.argv[1] == "resume" and sys.argv[2:] in ([], ["--stop-prepare"]):
        resume(stop_prepare=sys.argv[2:] == ["--stop-prepare"])
    else:
        raise SessionError("unsupported action")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"dsh-backup-session: {str(error)[:300]}", file=sys.stderr)
        raise SystemExit(1)

# 外接显示器断电后，把其上有窗口的工作区移到笔记本屏幕；恢复供电后移回原位。
#
# 判定依据：部分显示器断电后仍保持 HDMI 热插拔信号，Niri 看不到断开。此时只能
# 通过 DDC/CI 是否应答判断显示器是否有电。但 Niri 自身关闭显示器（dpms Off，如
# 锁屏后熄屏）时显示器进入待机，DDC 同样无应答，因此只在 Niri 正在驱动该输出
# （dpms On）时才把 DDC 失败计为断电。
#
# 不关闭 HDMI 输出：关闭后显示器早上来电也收不到信号，DDC 无法应答，就再也
# 探测不到恢复。

import json
import os
import socket
import subprocess
import sys
import time

SOURCE_OUTPUT = "HDMI-A-1"
FALLBACK_OUTPUT = "eDP-1"
DDCUTIL = os.environ.get("NIRI_OUTPUT_FALLBACK_DDCUTIL", "ddcutil")
POLL_SECONDS = 3
OFFLINE_AFTER = 3  # 连续失败次数，约 15 秒
ONLINE_AFTER = 2   # 连续应答次数
STATE_FILE = os.path.join(
    os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "niri-output-fallback.json"
)


def log(message):
    print(f"niri-output-fallback: {message}", file=sys.stderr, flush=True)


def request(payload):
    socket_path = os.environ.get("NIRI_SOCKET")
    if not socket_path:
        raise RuntimeError("NIRI_SOCKET is not available")

    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
        connection.connect(socket_path)
        connection.sendall((json.dumps(payload) + "\n").encode())
        reply = b""
        while not reply.endswith(b"\n"):
            chunk = connection.recv(65536)
            if not chunk:
                raise RuntimeError("Niri IPC closed before replying")
            reply += chunk

    decoded = json.loads(reply)
    if "Err" in decoded:
        raise RuntimeError(decoded["Err"])
    return decoded["Ok"]


def action(name, **arguments):
    request({"Action": {name: arguments}})


def connector_dir():
    base = "/sys/class/drm"
    for name in sorted(os.listdir(base)):
        if name.endswith("-" + SOURCE_OUTPUT):
            return os.path.join(base, name)
    return None


def read_text(path):
    try:
        with open(path) as handle:
            return handle.read().strip()
    except OSError:
        return None


def driven_by_niri():
    """HDMI 已连接且 Niri 正在输出画面；只有此时 DDC 失败才说明显示器断电。"""
    directory = connector_dir()
    if directory is None:
        return False
    return (
        read_text(os.path.join(directory, "status")) == "connected"
        and read_text(os.path.join(directory, "dpms")) == "On"
    )


def ddc_bus():
    directory = connector_dir()
    if directory is None:
        return None
    try:
        names = os.listdir(os.path.join(directory, "ddc", "i2c-dev"))
    except OSError:
        return None
    for name in names:
        if name.startswith("i2c-"):
            return name.removeprefix("i2c-")
    return None


def ddc_responds():
    """True：显示器应答 DDC；False：无应答；None：无法探测。"""
    bus = ddc_bus()
    if bus is None:
        return None
    try:
        result = subprocess.run(
            [DDCUTIL, "--syslog=NEVER", "--brief", "--bus", bus, "getvcp", "D6"],
            capture_output=True,
            check=False,
            text=True,
            timeout=5,
        )
    except subprocess.TimeoutExpired:
        return False
    except OSError:
        return None
    return result.returncode == 0


def load_moved():
    try:
        with open(STATE_FILE) as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return []


def save_moved(moved):
    if not moved:
        try:
            os.remove(STATE_FILE)
        except FileNotFoundError:
            pass
        return
    with open(STATE_FILE, "w") as handle:
        json.dump(moved, handle)


def move_to_fallback(moved):
    """移走外接屏上有窗口的工作区；空工作区由 Niri 自动维护，移走只会被重建。"""
    outputs = request("Outputs")["Outputs"]
    if FALLBACK_OUTPUT not in outputs:
        return moved

    known = {entry["id"] for entry in moved}
    workspaces = sorted(request("Workspaces")["Workspaces"], key=lambda w: w["idx"])
    changed = False
    for workspace in workspaces:
        if workspace.get("output") != SOURCE_OUTPUT:
            continue
        if workspace.get("active_window_id") is None:
            continue
        action(
            "MoveWorkspaceToMonitor",
            output=FALLBACK_OUTPUT,
            reference={"Id": workspace["id"]},
        )
        if workspace["id"] not in known:
            moved.append({"id": workspace["id"], "idx": workspace["idx"]})
        changed = True

    if changed:
        action("FocusMonitor", output=FALLBACK_OUTPUT)
        save_moved(moved)
    return moved


def move_back(moved):
    outputs = request("Outputs")["Outputs"]
    if SOURCE_OUTPUT not in outputs or not moved:
        return []

    existing = {w["id"] for w in request("Workspaces")["Workspaces"]}
    for entry in sorted(moved, key=lambda e: e["idx"]):
        if entry["id"] not in existing:
            continue
        reference = {"Id": entry["id"]}
        action("MoveWorkspaceToMonitor", output=SOURCE_OUTPUT, reference=reference)
        # idx 从 1 开始，MoveWorkspaceToIndex 的 index 同样从 1 开始。
        action("MoveWorkspaceToIndex", index=entry["idx"], reference=reference)

    action("FocusMonitor", output=SOURCE_OUTPUT)
    save_moved([])
    return []


def main():
    if "--force" in sys.argv[1:]:
        moved = move_to_fallback(load_moved())
        log(f"forced move of {len(moved)} workspace(s)")
        return
    if "--restore" in sys.argv[1:]:
        move_back(load_moved())
        log("forced restore")
        return

    moved = load_moved()
    offline = bool(moved)
    failures = 0
    successes = 0

    while True:
        try:
            if driven_by_niri():
                responds = ddc_responds()
                if responds is True:
                    failures = 0
                    successes += 1
                    if offline and successes >= ONLINE_AFTER:
                        log("monitor answers DDC again; restoring workspaces")
                        moved = move_back(moved)
                        offline = False
                elif responds is False:
                    successes = 0
                    failures += 1
                    if not offline and failures >= OFFLINE_AFTER:
                        log("monitor stopped answering DDC; moving workspaces")
                        offline = True
                    if offline:
                        # 断电期间新出现在外接屏上的窗口也一并移走。
                        moved = move_to_fallback(moved)
            else:
                # Niri 未驱动该输出（熄屏、锁屏或拔线）：不判断，计数清零。
                failures = 0
                successes = 0
        except (OSError, RuntimeError, ValueError, KeyError) as error:
            log(str(error))
        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    main()

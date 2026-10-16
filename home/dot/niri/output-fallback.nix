# ---
# Module: Niri Output Fallback
# Description: Move workspaces from the external monitor to the internal display after a physical disconnect
# Scope: Home Manager
# ---
# Notes:
# - Some monitors retain HDMI hotplug while powered off, so Niri cannot observe that state as a disconnect.
# - A retained HDMI hotplug plus failed or standby/off DDC reads is treated as an externally powered-off monitor.
# - The raw Niri IPC path preserves unique workspace IDs, unlike CLI indices which may overlap across outputs.

{ pkgs, ... }:
let
  niri-output-fallback = pkgs.writeShellScriptBin "niri-output-fallback" ''
    exec ${pkgs.python3}/bin/python3 - "$@" <<'PY'
    import json
    import glob
    import os
    import select
    import socket
    import subprocess
    import sys
    import time

    SOURCE_OUTPUT = "HDMI-A-1"
    FALLBACK_OUTPUT = "eDP-1"
    DDCUTIL = "${pkgs.ddcutil}/bin/ddcutil"
    DDC_FAILURE_LIMIT = 2
    DDC_POLL_SECONDS = 3

    ddc_failures = 0
    ddc_unavailable = False

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

    def move_external_workspaces(force=False):
        outputs = request("Outputs")["Outputs"]
        if FALLBACK_OUTPUT not in outputs or (not force and SOURCE_OUTPUT in outputs):
            return

        workspaces = request("Workspaces")["Workspaces"]
        for workspace in workspaces:
            if workspace.get("output") != SOURCE_OUTPUT:
                continue

            request({
                "Action": {
                    "MoveWorkspaceToMonitor": {
                        "output": FALLBACK_OUTPUT,
                        "reference": {"Id": workspace["id"]},
                    }
                }
            })

    def ddc_bus_numbers():
        buses = []
        for path in glob.glob("/sys/class/drm/card*-HDMI-A-1/ddc/i2c-dev/i2c-*"):
            name = os.path.basename(path)
            try:
                buses.append(int(name.removeprefix("i2c-")))
            except ValueError:
                continue
        return buses

    def is_dpm_on(output_text):
        text = output_text.lower()
        for line in text.splitlines():
            parts = line.strip().split()
            if len(parts) >= 4 and parts[0] == "vcp" and parts[1] in ("d6", "0xd6"):
                val = parts[-1]
                if val == "x01":
                    return True
                if val in ("x02", "x03", "x04", "x05"):
                    return False
        if "dpm: on" in text:
            return True
        if any(s in text for s in ("dpm: off", "dpm: standby", "dpm: suspend")):
            return False
        return None

    def ddc_display_state():
        buses = ddc_bus_numbers()
        if not buses:
            return None

        saw_on = False
        saw_off = False

        for bus in buses:
            try:
                result = subprocess.run(
                    [DDCUTIL, "--brief", "--bus", str(bus), "getvcp", "D6"],
                    capture_output=True,
                    check=False,
                    text=True,
                    timeout=2,
                )
            except (OSError, subprocess.TimeoutExpired):
                continue

            if result.returncode != 0:
                continue

            dpm = is_dpm_on(f"{result.stdout}\n{result.stderr}")
            if dpm is True:
                saw_on = True
                break
            elif dpm is False:
                saw_off = True

        if saw_on:
            return True
        if saw_off:
            return False
        return False

    def monitor_ddc_power():
        global ddc_failures, ddc_unavailable

        state = ddc_display_state()
        if state is None:
            return

        if state:
            if ddc_unavailable:
                print("niri-output-fallback: HDMI DDC response restored", file=sys.stderr)
            ddc_failures = 0
            ddc_unavailable = False
            return

        ddc_failures += 1
        if ddc_failures < DDC_FAILURE_LIMIT:
            if ddc_unavailable:
                move_external_workspaces(force=True)
            return

        if not ddc_unavailable:
            ddc_unavailable = True
            print(f"niri-output-fallback: HDMI DDC offline ({ddc_failures} checks); moving workspaces", file=sys.stderr)

        move_external_workspaces(force=True)

    if "--force" in sys.argv[1:]:
        move_external_workspaces(force=True)
        raise SystemExit(0)

    def event_stream():
        socket_path = os.environ.get("NIRI_SOCKET")
        if not socket_path:
            raise RuntimeError("NIRI_SOCKET is not available")

        connection = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        connection.connect(socket_path)
        connection.sendall(b'"EventStream"\n')
        stream = connection.makefile("rb")

        reply = json.loads(stream.readline())
        if reply != {"Ok": "Handled"}:
            raise RuntimeError("Niri rejected the event stream")

        while True:
            readable, _, _ = select.select([connection], [], [], DDC_POLL_SECONDS)
            if not readable:
                yield None
                continue

            line = stream.readline()
            if not line:
                raise RuntimeError("Niri IPC closed event stream")
            yield json.loads(line)

    while True:
        try:
            move_external_workspaces(force=ddc_unavailable)
            monitor_ddc_power()
            for event in event_stream():
                if event is None:
                    monitor_ddc_power()
                    continue

                if "WorkspacesChanged" not in event:
                    continue

                # Niri reports an output disconnect through the workspace state.
                time.sleep(0.15)
                move_external_workspaces(force=ddc_unavailable)
                monitor_ddc_power()
        except (OSError, RuntimeError, ValueError, KeyError) as error:
            print(f"niri-output-fallback: {error}", file=sys.stderr)
            time.sleep(2)
    PY
  '';
in
{
  home.packages = [ niri-output-fallback ];

  systemd.user.services.niri-output-fallback = {
    Unit = {
      Description = "Move external Niri workspaces to the internal display after disconnect";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${niri-output-fallback}/bin/niri-output-fallback";
      Restart = "on-failure";
      RestartSec = 2;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}

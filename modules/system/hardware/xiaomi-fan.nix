# ---
# Module: Xiaomi WMI Fan Mode Override
# Description: Provides privileged ACPI calls for Xiaomi thermal performance modes
# Scope: System
# Notes:
# - This bypasses the buggy bitland_mifs_wmi fan control path on Warden.
# - The public xiaomi-fan-mode command delegates to a root setuid wrapper.
# ---
{ pkgs, ... }:

let
  xiaomiFanModeRoot = pkgs.writeShellApplication {
    name = "xiaomi-fan-mode-root";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.kmod
    ];
    text = ''
      usage() {
        echo "Usage: xiaomi-fan-mode-root [quiet|balanced|performance|full-speed]" >&2
      }

      if [ "$#" -ne 1 ]; then
        usage
        exit 64
      fi

      case "$1" in
        quiet|low-power)
          mode="quiet"
          call='\_SB.PC00.WMID.WMAA 1 1 {0x00,0xFB,0x00,0x08,0x02,0x00,0x00,0x00,0x00,0x00}'
          ;;
        balanced)
          mode="balanced"
          call='\_SB.PC00.WMID.WMAA 1 1 {0x00,0xFB,0x00,0x08,0x01,0x00,0x00,0x00,0x00,0x00}'
          ;;
        performance|berserk)
          mode="performance"
          call='\_SB.PC00.WMID.WMAA 1 1 {0x00,0xFB,0x00,0x08,0x03,0x00,0x00,0x00,0x00,0x00}'
          ;;
        full-speed|max)
          mode="full-speed"
          call='\_SB.PC00.WMID.WMAA 1 1 {0x00,0xFB,0x00,0x08,0x04,0x00,0x00,0x00,0x00,0x00}'
          ;;
        *)
          echo "Unknown mode: $1" >&2
          usage
          exit 64
          ;;
      esac

      if [ "$(id -u)" -ne 0 ]; then
        echo "xiaomi-fan-mode-root must run as root" >&2
        exit 1
      fi

      if [ ! -e /proc/acpi/call ]; then
        modprobe acpi_call 2>/dev/null || true
      fi

      if [ ! -w /proc/acpi/call ]; then
        echo "/proc/acpi/call is not writable; is acpi_call loaded?" >&2
        exit 1
      fi

      printf '%s\n' "$call" > /proc/acpi/call
      result="$(cat /proc/acpi/call 2>/dev/null || true)"

      case "$result" in
        *Error*|*error*)
          echo "ACPI fan mode call failed: $result" >&2
          exit 1
          ;;
      esac

      echo "xiaomi fan mode: $mode"
    '';
  };

  xiaomiFanMode = pkgs.writeShellScriptBin "xiaomi-fan-mode" ''
    if [ "$#" -ne 1 ]; then
      echo "Usage: xiaomi-fan-mode [quiet|balanced|performance|full-speed]" >&2
      exit 1
    fi

    if [ "$(id -u)" -eq 0 ]; then
      exec ${xiaomiFanModeRoot}/bin/xiaomi-fan-mode-root "$@"
    fi

    if [ -x /run/wrappers/bin/xiaomi-fan-mode-root ]; then
      exec /run/wrappers/bin/xiaomi-fan-mode-root "$@"
    fi

    echo "Missing /run/wrappers/bin/xiaomi-fan-mode-root; rebuild the system first." >&2
    exit 1
  '';
in
{
  security.wrappers.xiaomi-fan-mode-root = {
    source = "${xiaomiFanModeRoot}/bin/xiaomi-fan-mode-root";
    owner = "root";
    group = "root";
    setuid = true;
    permissions = "u+rx,g+rx,o+rx";
  };

  environment.systemPackages = [
    xiaomiFanMode
  ];
}

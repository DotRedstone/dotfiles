# ---
# Module: Gaming - GameMode
# Description: Feral GameMode integration with Warden power-mode dispatch
# Scope: System
# Notes:
# - GameMode's native helper authorization requires membership in the gamemode group.
# - Fan mode switching is delegated to the Xiaomi setuid wrapper.
# ---

{ pkgs, ... }:

let
  gamingPowerModeRoot = pkgs.writeShellApplication {
    name = "gaming-power-mode-root";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
    ];
    text = ''
      set -u

      write_value() {
        file="$1"
        value="$2"

        if [ -w "$file" ]; then
          printf '%s\n' "$value" > "$file" 2>/dev/null || true
        fi
      }

      set_platform_profile() {
        profile="$1"

        if [ -r /sys/firmware/acpi/platform_profile_choices ] \
          && grep -qw "$profile" /sys/firmware/acpi/platform_profile_choices; then
          write_value /sys/firmware/acpi/platform_profile "$profile"
        fi
      }

      set_governor() {
        governor="$1"

        for policy in /sys/devices/system/cpu/cpufreq/policy*; do
          [ -d "$policy" ] || continue
          if [ -r "$policy/scaling_available_governors" ] \
            && grep -qw "$governor" "$policy/scaling_available_governors"; then
            write_value "$policy/scaling_governor" "$governor"
          fi
        done
      }

      set_energy_preference() {
        preference="$1"

        for policy in /sys/devices/system/cpu/cpufreq/policy*; do
          [ -d "$policy" ] || continue
          if [ -r "$policy/energy_performance_available_preferences" ] \
            && grep -qw "$preference" "$policy/energy_performance_available_preferences"; then
            write_value "$policy/energy_performance_preference" "$preference"
          fi
        done
      }

      set_energy_bias() {
        bias="$1"

        for file in /sys/devices/system/cpu/cpu*/power/energy_perf_bias; do
          [ -e "$file" ] || continue
          write_value "$file" "$bias"
        done
      }

      set_intel_pstate() {
        mode="$1"

        case "$mode" in
          performance)
            write_value /sys/devices/system/cpu/intel_pstate/no_turbo 0
            write_value /sys/devices/system/cpu/intel_pstate/hwp_dynamic_boost 1
            ;;
          balanced)
            write_value /sys/devices/system/cpu/intel_pstate/hwp_dynamic_boost 0
            ;;
        esac
      }

      case "''${1:-}" in
        start|performance|full-speed|max)
          set_platform_profile performance
          set_governor performance
          set_energy_preference performance
          set_energy_bias 0
          set_intel_pstate performance
          ;;
        end|balanced)
          set_platform_profile balanced
          set_governor powersave
          set_energy_preference balance_performance
          set_energy_bias 6
          set_intel_pstate balanced
          ;;
        *)
          echo "Usage: gaming-power-mode-root [start|end|performance|balanced|full-speed]" >&2
          exit 64
          ;;
      esac
    '';
  };

  gamingPowerMode = pkgs.writeShellApplication {
    name = "gaming-power-mode";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.power-profiles-daemon
    ];
    text = ''
      set -u

      log() {
        echo "gaming-power-mode: $*" >&2
      }

      set_system_mode() {
        mode="$1"

        if [ -x /run/wrappers/bin/gaming-power-mode-root ]; then
          /run/wrappers/bin/gaming-power-mode-root "$mode" >/dev/null 2>&1 \
            || log "root power dispatcher could not set $mode"
        else
          log "root power dispatcher is unavailable"
        fi
      }

      set_power_profile() {
        profile="$1"

        if command -v powerprofilesctl >/dev/null 2>&1; then
          powerprofilesctl set "$profile" >/dev/null 2>&1 || log "powerprofilesctl could not set $profile"
        fi

        if [ -r /sys/firmware/acpi/platform_profile_choices ] \
          && grep -qw "$profile" /sys/firmware/acpi/platform_profile_choices \
          && [ -w /sys/firmware/acpi/platform_profile ]; then
          printf '%s\n' "$profile" > /sys/firmware/acpi/platform_profile 2>/dev/null \
            || log "platform_profile could not set $profile"
        fi
      }

      set_fan_mode() {
        mode="$1"

        if [ -x /run/wrappers/bin/xiaomi-fan-mode-root ]; then
          /run/wrappers/bin/xiaomi-fan-mode-root "$mode" >/dev/null 2>&1 \
            || log "xiaomi fan mode could not set $mode"
        elif command -v xiaomi-fan-mode >/dev/null 2>&1; then
          xiaomi-fan-mode "$mode" >/dev/null 2>&1 \
            || log "xiaomi fan mode command could not set $mode"
        else
          log "xiaomi fan mode command is unavailable"
        fi
      }

      case "''${1:-}" in
        start|performance)
          set_system_mode performance
          set_power_profile performance
          set_fan_mode "''${GAMING_FAN_MODE:-performance}"
          ;;
        end|balanced)
          set_system_mode balanced
          set_power_profile balanced
          set_fan_mode balanced
          ;;
        full-speed|max)
          set_system_mode full-speed
          set_power_profile performance
          set_fan_mode full-speed
          ;;
        *)
          echo "Usage: gaming-power-mode [start|end|performance|balanced|full-speed]" >&2
          exit 64
          ;;
      esac

      exit 0
    '';
  };
in
{
  security.wrappers.gaming-power-mode-root = {
    source = "${gamingPowerModeRoot}/bin/gaming-power-mode-root";
    owner = "root";
    group = "root";
    setuid = true;
    permissions = "u+rx,g+rx,o+rx";
  };

  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        desiredgov = "performance";
        defaultgov = "powersave";
        igpu_power_threshold = "-1";
        renice = "10";
        softrealtime = "off";
      };
      cpu = {
        park_cores = "no";
        pin_cores = "yes";
      };
      custom = {
        start = "${gamingPowerMode}/bin/gaming-power-mode start";
        end = "${gamingPowerMode}/bin/gaming-power-mode end";
        script_timeout = "10";
      };
    };
  };

  users.users.dot.extraGroups = [ "gamemode" ];

  environment.systemPackages = [
    gamingPowerMode
  ];
}

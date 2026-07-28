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
  gamingPowerModeRootSource = pkgs.writeText "gaming-power-mode-root.c" ''
    #include <ctype.h>
    #include <dirent.h>
    #include <errno.h>
    #include <glob.h>
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    #include <unistd.h>

    static int write_value(const char *path, const char *value) {
      FILE *file = fopen(path, "w");
      if (file == NULL) {
        return -1;
      }

      int rc = fprintf(file, "%s\n", value) < 0 ? -1 : 0;
      if (fclose(file) != 0) {
        rc = -1;
      }
      return rc;
    }

    static int read_file(const char *path, char *buffer, size_t size) {
      FILE *file = fopen(path, "r");
      if (file == NULL) {
        return -1;
      }

      size_t read = fread(buffer, 1, size - 1, file);
      buffer[read] = '\0';
      fclose(file);
      return 0;
    }

    static void trim_trailing_space(char *value) {
      size_t length = strlen(value);
      while (length > 0 && isspace((unsigned char)value[length - 1])) {
        value[length - 1] = '\0';
        length--;
      }
    }

    static int contains_word(const char *path, const char *word) {
      char buffer[4096];
      if (read_file(path, buffer, sizeof(buffer)) != 0) {
        return 0;
      }

      char *cursor = buffer;
      while (*cursor != '\0') {
        while (isspace((unsigned char)*cursor)) {
          cursor++;
        }
        char *start = cursor;
        while (*cursor != '\0' && !isspace((unsigned char)*cursor)) {
          cursor++;
        }
        if ((size_t)(cursor - start) == strlen(word) &&
            strncmp(start, word, (size_t)(cursor - start)) == 0) {
          return 1;
        }
      }
      return 0;
    }

    static int set_platform_profile(const char *profile) {
      const char *choices = "/sys/firmware/acpi/platform_profile_choices";
      const char *profile_path = "/sys/firmware/acpi/platform_profile";

      if (access(choices, R_OK) != 0) {
        return 0;
      }
      if (!contains_word(choices, profile)) {
        return 0;
      }

      char current[128];
      if (read_file(profile_path, current, sizeof(current)) == 0) {
        trim_trailing_space(current);
        if (strcmp(current, profile) == 0) {
          return 0;
        }
      }

      if (write_value(profile_path, profile) != 0) {
        fprintf(stderr, "failed to write %s: %s\n", profile_path, strerror(errno));
        return 1;
      }
      return 0;
    }

    static int set_policy_value(const char *available_name, const char *target_name, const char *value) {
      DIR *dir = opendir("/sys/devices/system/cpu/cpufreq");
      if (dir == NULL) {
        return 0;
      }

      int errors = 0;
      struct dirent *entry;
      while ((entry = readdir(dir)) != NULL) {
        if (strncmp(entry->d_name, "policy", 6) != 0) {
          continue;
        }

        char available_path[512];
        char target_path[512];
        snprintf(available_path, sizeof(available_path),
          "/sys/devices/system/cpu/cpufreq/%s/%s", entry->d_name, available_name);
        snprintf(target_path, sizeof(target_path),
          "/sys/devices/system/cpu/cpufreq/%s/%s", entry->d_name, target_name);

        if (access(available_path, R_OK) == 0 && contains_word(available_path, value)) {
          if (write_value(target_path, value) != 0) {
            errors++;
          }
        }
      }

      closedir(dir);
      return errors;
    }

    static int set_energy_bias(const char *value) {
      glob_t matches;
      int rc = glob("/sys/devices/system/cpu/cpu*/power/energy_perf_bias", 0, NULL, &matches);
      if (rc != 0) {
        return 0;
      }

      int errors = 0;
      for (size_t i = 0; i < matches.gl_pathc; i++) {
        if (write_value(matches.gl_pathv[i], value) != 0) {
          errors++;
        }
      }
      globfree(&matches);
      return errors;
    }

    static void set_intel_pstate_performance(void) {
      write_value("/sys/devices/system/cpu/intel_pstate/no_turbo", "0");
      write_value("/sys/devices/system/cpu/intel_pstate/hwp_dynamic_boost", "1");
    }

    static void set_intel_pstate_balanced(void) {
      write_value("/sys/devices/system/cpu/intel_pstate/no_turbo", "0");
      write_value("/sys/devices/system/cpu/intel_pstate/hwp_dynamic_boost", "0");
    }

    static void set_intel_pstate_power_saver(void) {
      write_value("/sys/devices/system/cpu/intel_pstate/no_turbo", "1");
      write_value("/sys/devices/system/cpu/intel_pstate/hwp_dynamic_boost", "0");
    }

    static void usage(void) {
      fprintf(stderr, "Usage: gaming-power-mode-root [power-saver|balanced|balanced-performance|performance|full-speed]\n");
    }

    int main(int argc, char **argv) {
      if (argc != 2) {
        usage();
        return 64;
      }

      if (setgid(0) != 0 || setuid(0) != 0) {
        fprintf(stderr, "failed to keep root privileges: %s\n", strerror(errno));
        return 1;
      }

      const char *mode = argv[1];
      if (strcmp(mode, "power-saver") == 0 ||
          strcmp(mode, "low-power") == 0 ||
          strcmp(mode, "quiet") == 0) {
        int profile_status = set_platform_profile("low-power");
        set_policy_value("scaling_available_governors", "scaling_governor", "powersave");
        set_policy_value("energy_performance_available_preferences", "energy_performance_preference", "power");
        set_energy_bias("15");
        set_intel_pstate_power_saver();
        return profile_status == 0 ? 0 : 1;
      }

      if (strcmp(mode, "balanced-performance") == 0 ||
          strcmp(mode, "balance-performance") == 0) {
        int profile_status = set_platform_profile("balanced-performance");
        set_policy_value("scaling_available_governors", "scaling_governor", "performance");
        set_policy_value("energy_performance_available_preferences", "energy_performance_preference", "balance_performance");
        set_energy_bias("4");
        set_intel_pstate_performance();
        return profile_status == 0 ? 0 : 1;
      }

      if (strcmp(mode, "start") == 0 ||
          strcmp(mode, "performance") == 0 ||
          strcmp(mode, "full-speed") == 0 ||
          strcmp(mode, "max") == 0) {
        int profile_status = set_platform_profile("performance");
        set_policy_value("scaling_available_governors", "scaling_governor", "performance");
        set_policy_value("energy_performance_available_preferences", "energy_performance_preference", "performance");
        set_energy_bias("0");
        set_intel_pstate_performance();
        return profile_status == 0 ? 0 : 1;
      }

      if (strcmp(mode, "end") == 0 || strcmp(mode, "balanced") == 0) {
        int profile_status = set_platform_profile("balanced");
        set_policy_value("scaling_available_governors", "scaling_governor", "powersave");
        set_policy_value("energy_performance_available_preferences", "energy_performance_preference", "balance_performance");
        set_energy_bias("6");
        set_intel_pstate_balanced();
        return profile_status == 0 ? 0 : 1;
      }

      fprintf(stderr, "Unknown mode: %s\n", mode);
      usage();
      return 64;
    }
  '';

  gamingPowerModeRoot = pkgs.stdenv.mkDerivation {
    name = "gaming-power-mode-root";
    dontUnpack = true;
    buildPhase = ''
      runHook preBuild
      $CC -O2 -Wall -Wextra ${gamingPowerModeRootSource} -o gaming-power-mode-root
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      install -Dm755 gaming-power-mode-root "$out/bin/gaming-power-mode-root"
      runHook postInstall
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

      write_state() {
        state="$1"
        runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
        state_dir="$runtime_dir/gaming-power-mode"

        mkdir -p "$state_dir" 2>/dev/null || return 0
        printf '%s\n' "$state" > "$state_dir/state" 2>/dev/null || true
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
        platform_profile="''${2:-$profile}"

        current="$(cat /sys/firmware/acpi/platform_profile 2>/dev/null || true)"
        if [ "$current" = "$platform_profile" ]; then
          return 0
        fi

        if [ -n "$profile" ] && command -v powerprofilesctl >/dev/null 2>&1; then
          powerprofilesctl set "$profile" >/dev/null 2>&1 || log "powerprofilesctl could not set $profile"
        fi

        if [ -r /sys/firmware/acpi/platform_profile_choices ] \
          && grep -qw "$platform_profile" /sys/firmware/acpi/platform_profile_choices \
          && [ -w /sys/firmware/acpi/platform_profile ]; then
          printf '%s\n' "$platform_profile" > /sys/firmware/acpi/platform_profile 2>/dev/null \
            || log "platform_profile could not set $platform_profile"
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
        power-saver|low-power|quiet)
          set_fan_mode quiet
          set_system_mode power-saver
          set_power_profile power-saver low-power
          write_state power-saver
          ;;
        balanced-performance|balance-performance)
          set_fan_mode balanced
          set_system_mode balanced-performance
          set_power_profile "" balanced-performance
          write_state balanced-performance
          ;;
        start|performance)
          set_fan_mode "''${GAMING_FAN_MODE:-performance}"
          set_system_mode performance
          set_power_profile performance
          write_state performance
          ;;
        end|balanced)
          set_fan_mode balanced
          set_system_mode balanced
          set_power_profile balanced
          write_state balanced
          ;;
        full-speed|max)
          set_fan_mode full-speed
          set_system_mode full-speed
          set_power_profile performance
          write_state full-speed
          ;;
        *)
          echo "Usage: gaming-power-mode [power-saver|balanced|balanced-performance|performance|full-speed]" >&2
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

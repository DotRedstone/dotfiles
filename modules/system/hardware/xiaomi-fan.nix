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
  xiaomiFanModeRootSource = pkgs.writeText "xiaomi-fan-mode-root.c" ''
    #include <errno.h>
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    #include <sys/types.h>
    #include <sys/wait.h>
    #include <unistd.h>

    static const char *modprobe_path = "${pkgs.kmod}/bin/modprobe";

    struct fan_mode {
      const char *name;
      const char *call;
    };

    static void usage(void) {
      fprintf(stderr, "Usage: xiaomi-fan-mode-root [quiet|balanced|performance|full-speed]\n");
    }

    static const struct fan_mode *resolve_mode(const char *arg) {
      static const struct fan_mode quiet = {
        "quiet",
        "\\\\_SB.PC00.WMID.WMAA 1 1 {0x00,0xFB,0x00,0x08,0x02,0x00,0x00,0x00,0x00,0x00}"
      };
      static const struct fan_mode balanced = {
        "balanced",
        "\\\\_SB.PC00.WMID.WMAA 1 1 {0x00,0xFB,0x00,0x08,0x01,0x00,0x00,0x00,0x00,0x00}"
      };
      static const struct fan_mode performance = {
        "performance",
        "\\\\_SB.PC00.WMID.WMAA 1 1 {0x00,0xFB,0x00,0x08,0x03,0x00,0x00,0x00,0x00,0x00}"
      };
      static const struct fan_mode full_speed = {
        "full-speed",
        "\\\\_SB.PC00.WMID.WMAA 1 1 {0x00,0xFB,0x00,0x08,0x04,0x00,0x00,0x00,0x00,0x00}"
      };

      if (strcmp(arg, "quiet") == 0 || strcmp(arg, "low-power") == 0) {
        return &quiet;
      }
      if (strcmp(arg, "balanced") == 0) {
        return &balanced;
      }
      if (strcmp(arg, "performance") == 0 || strcmp(arg, "berserk") == 0) {
        return &performance;
      }
      if (strcmp(arg, "full-speed") == 0 || strcmp(arg, "max") == 0) {
        return &full_speed;
      }
      return NULL;
    }

    static int run_modprobe(void) {
      pid_t pid = fork();
      if (pid < 0) {
        return -1;
      }
      if (pid == 0) {
        execl(modprobe_path, "modprobe", "acpi_call", (char *)NULL);
        _exit(127);
      }

      int status = 0;
      if (waitpid(pid, &status, 0) < 0) {
        return -1;
      }
      return WIFEXITED(status) ? WEXITSTATUS(status) : -1;
    }

    static int ensure_acpi_call(void) {
      if (access("/proc/acpi/call", W_OK) == 0) {
        return 0;
      }

      run_modprobe();
      if (access("/proc/acpi/call", W_OK) != 0) {
        fprintf(stderr, "/proc/acpi/call is not writable; is acpi_call loaded? %s\n", strerror(errno));
        return 1;
      }
      return 0;
    }

    static int call_acpi(const char *call, char *result, size_t result_size) {
      FILE *file = fopen("/proc/acpi/call", "w");
      if (file == NULL) {
        fprintf(stderr, "failed to open /proc/acpi/call for write: %s\n", strerror(errno));
        return 1;
      }

      int write_failed = fprintf(file, "%s\n", call) < 0;
      if (fclose(file) != 0 || write_failed) {
        fprintf(stderr, "failed to write /proc/acpi/call: %s\n", strerror(errno));
        return 1;
      }

      file = fopen("/proc/acpi/call", "r");
      if (file == NULL) {
        result[0] = '\0';
        return 0;
      }

      size_t read = fread(result, 1, result_size - 1, file);
      result[read] = '\0';
      fclose(file);
      return 0;
    }

    int main(int argc, char **argv) {
      if (argc != 2) {
        usage();
        return 64;
      }

      const struct fan_mode *mode = resolve_mode(argv[1]);
      if (mode == NULL) {
        fprintf(stderr, "Unknown mode: %s\n", argv[1]);
        usage();
        return 64;
      }

      if (setgid(0) != 0 || setuid(0) != 0) {
        fprintf(stderr, "xiaomi-fan-mode-root must run as root: %s\n", strerror(errno));
        return 1;
      }

      if (ensure_acpi_call() != 0) {
        return 1;
      }

      char result[512];
      if (call_acpi(mode->call, result, sizeof(result)) != 0) {
        return 1;
      }

      if (strstr(result, "Error") != NULL || strstr(result, "error") != NULL) {
        fprintf(stderr, "ACPI fan mode call failed: %s\n", result);
        return 1;
      }

      printf("xiaomi fan mode: %s\n", mode->name);
      return 0;
    }
  '';

  xiaomiFanModeRoot = pkgs.stdenv.mkDerivation {
    name = "xiaomi-fan-mode-root";
    dontUnpack = true;
    buildPhase = ''
      runHook preBuild
      $CC -O2 -Wall -Wextra ${xiaomiFanModeRootSource} -o xiaomi-fan-mode-root
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      install -Dm755 xiaomi-fan-mode-root "$out/bin/xiaomi-fan-mode-root"
      runHook postInstall
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

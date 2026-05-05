# ---
# Module: Boot - Kernel
# Description: Kernel package selection, modules, and parameters
# Scope: System
# ---

{ pkgs, ... }: {
  # [Kernel]
  # Using latest kernel for better Intel Ultra 7 155H (Meteor Lake) support
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [ "kvm-intel" ];
  boot.kernelParams = [
    "quiet" "splash" "boot.shell_on_fail" "loglevel=3"
    "rd.systemd.show_status=false" "rd.udev.log_level=3"
    "udev.log_priority=3" "vt.global_cursor_default=0"
  ];

  # [Security]
  # Allow WeChat Notify Bridge to read WeChat memory for SQLCipher keys.
  boot.kernel.sysctl."kernel.yama.ptrace_scope" = 0;
}

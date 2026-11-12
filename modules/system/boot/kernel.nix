# ---
# Module: Boot - Kernel
# Description: Kernel package selection, modules, and parameters
# Scope: System
# ---

{ pkgs, ... }: {
  # [Kernel]
  # Using latest kernel for better Intel Ultra 7 155H (Meteor Lake) support
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [ "kvm-intel" "tcp_bbr" ];
  boot.kernelParams = [
    "quiet" "splash" "boot.shell_on_fail" "loglevel=3"
    "rd.systemd.show_status=false" "rd.udev.log_level=3"
    "udev.log_priority=3" "vt.global_cursor_default=0"
  ];

  # [Security]
  # Allow WeChat Notify Bridge to read WeChat memory for SQLCipher keys.
  boot.kernel.sysctl."kernel.yama.ptrace_scope" = 0;

  # [Network Performance]
  # Enable BBR congestion control and Fair Queueing for low latency and packet loss resilience
  boot.kernel.sysctl."net.core.default_qdisc" = "fq";
  boot.kernel.sysctl."net.ipv4.tcp_congestion_control" = "bbr";
  boot.kernel.sysctl."net.ipv4.tcp_fastopen" = 3;

  # [SysRq]
  # 系统卡死时用于诊断和安全重启（曾在低电量休眠入口卡死，无日志落盘）：
  # DUMP 0x08（W 列出阻塞任务、C 触发崩溃并由 efi_pstore 保存内核日志）、
  # SYNC 0x10（S）、REMOUNT 0x20（U）、BOOT 0x80（B）。不开放键盘控制、
  # 信号与实时优先级调整。
  boot.kernel.sysctl."kernel.sysrq" = 184;
}

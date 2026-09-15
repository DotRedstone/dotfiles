# ---
# Module: Server TCP BBR
# Description: Enable BBR congestion control with the fair-queueing scheduler
# Scope: System
# ---

{ ... }: {
  boot.kernelModules = [ "tcp_bbr" ];

  boot.kernel.sysctl = {
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };
}

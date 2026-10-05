# ---
# Module: System - Coredump Limits
# Description: Storage limits and retention rules for systemd-coredump
# Scope: System
# ---

{ ... }: {
  # [Coredump Limits]
  systemd.coredump = {
    enable = true;
    settings = {
      Coredump = {
        Storage = "external";
        Compress = true;
        MaxUse = "500M";
        KeepFree = "10G";
      };
    };
  };

  # [Retention Rules]
  systemd.tmpfiles.rules = [
    "d /var/lib/systemd/coredump 0755 root root 7d"
  ];
}

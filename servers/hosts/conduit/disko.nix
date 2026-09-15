# ---
# Module: Conduit Disk Layout
# Description: Destructive BIOS-GPT and ext4 layout for the RackNerd system disk
# Scope: Host
# Notes:
# - Applying this layout erases every partition on /dev/vda.
# - The device path was verified against the live RackNerd VM.
# ---

{ ... }: {
  disko.devices.disk.system = {
    type = "disk";
    device = "/dev/vda";
    content = {
      type = "gpt";
      partitions = {
        boot = {
          priority = 1;
          size = "1M";
          type = "EF02";
        };

        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
            extraArgs = [
              "-L"
              "nixos"
            ];
          };
        };
      };
    };
  };
}

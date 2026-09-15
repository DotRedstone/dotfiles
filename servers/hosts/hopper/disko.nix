# ---
# Module: Hopper Disk Layout
# Description: Destructive UEFI-GPT and ext4 layout for the Oracle boot volume
# Scope: Host
# Notes:
# - Applying this layout erases every partition on /dev/sda.
# - The device path was verified against the live Oracle A1 VM.
# ---

{ ... }: {
  disko.devices.disk.system = {
    type = "disk";
    device = "/dev/sda";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 1;
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
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

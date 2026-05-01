# ---
# Module: Boot Compatibility Shim
# Description: Imports the atomized boot module tree
# Scope: System
# Notes:
# - Rollback script depends on the Btrfs root device and subvolume layout
# ---

{ ... }: {
  imports = [ ./boot ];
}

# ---
# Module: System Switchboard
# Description: Unified entry point for all system modules
# ---

{ ... }: {
  imports = [
    ./nix.nix           # Flake & Package settings
    ./boot.nix          # Rollback & Bootloader
    ./persistence.nix   # Warden Vault
    ./persist-snapshots.nix # Persist Data Protection
    ./users.nix         # dot's Identity
    ./i18n.nix          # Locale & Input
    ./hardware.nix      # Power, Audio, Bluetooth
    ./network.nix       # Connectivity
    ./desktop.nix       # Niri & Graphics
    ./fonts.nix         # Typography
    ./virtualization.nix# Docker & KVM
    ./keyd.nix          # Key Remapping
  ];
}

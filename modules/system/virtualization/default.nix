# ---
# Module: Virtualization Switchboard
# Description: Unified entry point for Docker and Libvirt modules
# Scope: System
# ---

{ ... }: {
  imports = [
    ./docker.nix
    ./libvirt.nix
    ./tools.nix
  ];
}

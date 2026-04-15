# ---
# Module: CLI Tools Entry
# Description: Consolidate core, modern, and network toolsets
# ---

{ ... }: {
  imports = [
    ./core.nix
    ./modern.nix
    ./network.nix
  ];
}

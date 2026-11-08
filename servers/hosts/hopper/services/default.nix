# ---
# Module: Entry
# Description: Imports Hopper-specific optional application services
# Scope: Host
# ---

{ ... }: {
  imports = [
    ./dsh.nix
    ./dsh-coding-agents.nix
    ./dsh-remote-server/service.nix
    ./workbuddy2api/service.nix
  ];
}

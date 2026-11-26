# ---
# Module: Direnv
# Description: Per-directory environment loader with nix-direnv caching
# Scope: Home Manager
# ---

{ ... }: {
  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    nix-direnv.enable = true;
  };
}

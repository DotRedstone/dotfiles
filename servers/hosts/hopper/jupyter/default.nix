# ---
# Module: Hopper Jupyter Switchboard
# Description: Unified entry point for JupyterHub services, extensions, users, settings, and PDF export
# Scope: Host
# ---

{ ... }: {
  imports = [
    ./env.nix
    ./packages.nix
    ./users.nix
    ./settings.nix
    ./pdf-export.nix
    ./service.nix
    ./reverse-proxy.nix
  ];
}

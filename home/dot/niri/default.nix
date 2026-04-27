# ---
# Module: Niri Window Manager
# Description: Scrollable-tiling Wayland compositor and environment
# ---

{ ... }: {
  imports = [
    ./packages.nix
    ./links.nix
  ];

  # [Session Variables]
  home.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    XDG_CURRENT_DESKTOP = "niri";
    XDG_SESSION_DESKTOP = "niri";
    XDG_SESSION_TYPE = "wayland";
  };
}

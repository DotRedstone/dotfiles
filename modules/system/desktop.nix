# ---
# Module: Desktop Environment
# Description: Niri compositor, SDDM greeter, and graphics acceleration
# ---

{ pkgs, inputs, ... }: {
  imports = [ inputs.silent-sddm.nixosModules.default ];

  # [Compositor & Display Manager]
  programs.niri.enable = true;
  services.displayManager.defaultSession = "niri";
  
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  programs.silentSDDM = {
    enable = true;
    theme = "rei";
  };

  # [Graphics & Drivers]
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver
      intel-compute-runtime
    ];
  };

  # [XDG Portals]
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
    config.niri.default = [ "gnome" "gtk" ];
  };

  # [Services]
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  services.devmon.enable = true;
  services.tumbler.enable = true;
  programs.dconf.enable = true;

  # [Theming]
  environment.systemPackages = [ pkgs.bibata-cursors ];
  environment.variables = {
    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE = "24";
  };
}

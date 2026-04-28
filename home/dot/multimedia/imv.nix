# ---
# Module: IMV
# Description: Lightweight image viewer for Wayland
# ---

{ pkgs, ... }: {
  programs.imv = {
    enable = true;
    settings = {
      options = {
        background = "000000";
        overlay_font = "Maple Mono NF:12";
        slideshow_duration = 3;
      };
    };
  };
}

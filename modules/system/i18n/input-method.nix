# ---
# Module: System Input Method
# Description: Configuration for Fcitx5 and Rime engine at the system level
# ---

{ pkgs, ... }: {
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [
        (fcitx5-rime.override { rimeDataPkgs = [ pkgs.rime-data pkgs.rime-ice ]; })
      ];
    };
  };
}

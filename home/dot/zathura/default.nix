# ---
# Module: Zathura
# Description: Highly customizable document viewer with Vim-like bindings
# Scope: Home Manager
# ---

{ pkgs, ... }: {
  programs.zathura = {
    enable = true;
    options = {
      font = "Maple Mono NF 11";
      guioptions = "none"; # Clean look, no scrollbars
      recolor = true;
      recolor-keephue = true;
      selection-clipboard = "clipboard";
      statusbar-h-padding = 10;
      statusbar-v-padding = 10;
    };
    extraConfig = ''
      include noctaliarc
    '';
  };
}

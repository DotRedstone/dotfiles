# ---
# Module: Zathura
# Description: Highly customizable document viewer with Vim-like bindings
# ---

{ pkgs, ... }: {
  programs.zathura = {
    enable = true;
    options = {
      recolor = true;
      recolor-keephue = true;
      
      # [Visuals]
      # Using a refined dark palette to match your theme
      default-bg = "#1e1e2e";
      default-fg = "#cdd6f4";
      recolor-lightcolor = "#1e1e2e";
      recolor-darkcolor = "#cdd6f4";
      
      # UI adjustments
      statusbar-h-padding = 10;
      statusbar-v-padding = 10;
      guioptions = "none"; # Clean look, no scrollbars
      font = "Maple Mono NF 11";
      
      selection-clipboard = "clipboard";
    };
  };
}

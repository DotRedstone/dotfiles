# ---
# Module: Zellij Multiplexer
# Description: Modern terminal multiplexer with mouse support and clean layout defaults
# Scope: Home Manager
# ---

{ ... }: {
  programs.zellij = {
    enable = true;
    enableFishIntegration = false;
    settings = {
      theme = "catppuccin-mocha";
      default_layout = "compact";
      mouse_mode = true;
      copy_on_select = true;
    };
  };
}

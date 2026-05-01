# ---
# Module: Cava
# Description: Console-based Audio Visualizer
# Scope: Home Manager
# ---

{ pkgs, ... }: {
  programs.cava = {
    enable = true;
    settings = {
      general = {
        # High-resolution bars
        framerate = 60;
        bars = 0; # Auto width
        bar_width = 2;
        bar_spacing = 1;
      };
      
      input = {
        method = "pipewire";
        source = "auto";
      };
      
      color = {
        # Using a sleek gradient to match your brown/warm theme
        gradient = 1;
        gradient_count = 8;
        gradient_color_1 = "'#ff9e64'";
        gradient_color_2 = "'#e0af68'";
        gradient_color_3 = "'#9ece6a'";
        gradient_color_4 = "'#73daca'";
        gradient_color_5 = "'#b4f9f8'";
        gradient_color_6 = "'#2ac3de'";
        gradient_color_7 = "'#7aa2f7'";
        gradient_color_8 = "'#bb9af7'";
      };
      
      smoothing = {
        integral = 77;
        monstercat = 1;
        waves = 0;
      };
    };
  };

  # Resolve activation conflict with existing regular file
  xdg.configFile."cava/config".force = true;
}

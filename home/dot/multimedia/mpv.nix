# ---
# Module: MPV
# Description: High-performance video player with modern UI (uosc)
# ---

{ pkgs, ... }: {
  programs.mpv = {
    enable = true;
    scripts = with pkgs.mpvScripts; [
      uosc      # Modern floating UI
      thumbfast # Fast seek previews
      mpris     # Media control integration
    ];
    
    config = {
      # [Visuals]
      osc = "no";          # Disable default OSC for uosc
      osd-bar = "no";      # Disable default OSD bar
      border = "no";       # No window border
      
      # [Performance]
      hwdec = "auto";      # Hardware acceleration
      gpu-context = "wayland";
      
      # [Subtitles]
      sub-auto = "fuzzy";
      sub-font = "Maple Mono NF";
      sub-font-size = 36;
    };
  };
}

# ---
# Module: Kitty Theming
# Description: Transparency, window decorations, and Noctalia integration
# ---

{ ... }: {
  programs.kitty.settings = {
    # [Color Theme]
    include = "themes/noctalia.conf";

    # [Window Transparency]
    # Complements Niri's compositor-level opacity
    background_opacity = "0.9";
    dynamic_background_opacity = "yes";
    background_blur = "0";

    # [UI Layout]
    hide_window_decorations = "yes";
    confirm_os_window_close = 0;
    window_padding_width = 4; # Adds a subtle breathing room
    
    # [Performance]
    input_delay = 1;
    repaint_delay = 8;
    sync_to_monitor = "yes";
  };
}

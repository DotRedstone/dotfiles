# ---
# Module: Firefox Theme
# Description: Minimalist CSS for Niri compositor integration
# Scope: Home Manager
# ---

{ ... }: {
  programs.firefox.profiles.dot.userChrome = ''
    /* Clean UI for tiled window managers */
    #navigator-toolbox {
      border: none !important;
    }
    #nav-bar, #PersonalToolbar, #TabsToolbar {
      border: none !important;
      box-shadow: none !important;
    }

    /* Hide tab bar if using vertical tabs or sidebar */
    /* #TabsToolbar { visibility: collapse !important; } */
  '';
}

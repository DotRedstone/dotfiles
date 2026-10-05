# ---
# Module: Firefox Theme
# Description: Minimalist CSS for Niri compositor integration
# Scope: Home Manager
# ---

{ ... }: {
  programs.firefox.profiles.dot = {
    userChrome = ''
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

    userContent = ''
      /* ==========================================================================
         Web Terminal & Monospace Typography Harmonization
         ========================================================================== */

      /* Ensure web terminals (JupyterLab xterm.js, etc.) use clean monospace with 0 letter-spacing */
      .xterm,
      .xterm .xterm-screen,
      .xterm .xterm-rows,
      .xterm-screen canvas,
      .jp-Terminal-body,
      .jp-Terminal {
        font-family: "Maple Mono NF", "Sarasa Mono SC", monospace !important;
        letter-spacing: 0px !important;
      }
    '';
  };
}

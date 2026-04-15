# ---
# Module: Keyd
# Description: Kernel-level key remapping for Super key consistency
# ---

{ ... }: {
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings = {
        # Map Meta (Super) combinations to safe global shortcuts for Wayland consistency
        meta = {
          c = "C-insert"; # Copy
          v = "S-insert"; # Paste
          x = "S-delete"; # Cut
          a = "C-a";      # Select All
          z = "C-z";      # Undo
        };
      };
    };
  };
}

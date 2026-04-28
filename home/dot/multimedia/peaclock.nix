# ---
# Module: Peaclock
# Description: Minimalist binary clock and timer
# ---

{ pkgs, ... }: {
  home.packages = [ pkgs.peaclock ];
  
  # Configuration is usually done via command line arguments, 
  # but we define it here for consistent management.
}

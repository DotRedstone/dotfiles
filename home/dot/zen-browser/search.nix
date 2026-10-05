# ---
# Module: Zen Browser - Search
# Description: Search engine configuration and default policies for Zen Browser
# Scope: Home Manager
# ---

{ ... }: {
  programs.zen-browser.profiles.dot = {
    search.force = true;
    search.default = "google";
    search.order = [ "google" ];
  };
}

# ---
# Module: Firefox - Search
# Description: Search engine configuration and default policies
# ---

{ ... }: {
  programs.firefox.profiles.dot = {
    search.force = true;
    search.default = "google";
    search.order = [ "google" ];
  };
}

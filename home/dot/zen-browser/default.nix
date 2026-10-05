# ---
# Module: Zen Browser Switchboard
# Description: Unified entry point for Zen Browser profile, settings, extensions, and integrations
# Scope: Home Manager
# ---

{ ... }: {
  imports = [
    ./profile.nix
    ./settings.nix
    ./extensions.nix
    ./search.nix
    ./theme.nix
    ./native-messaging.nix
  ];
}

# ---
# Module: i18n Entry
# Description: Unified entry point for system locale and input method configurations
# ---

{ ... }: {
  imports = [
    ./locale.nix
    ./environment.nix
    ./input-method.nix
    ./kmscon.nix
    ./machine-id.nix
  ];
}

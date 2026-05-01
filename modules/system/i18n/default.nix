# ---
# Module: i18n Entry
# Description: Import switchboard for system localization and input methods
# Scope: System
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

# ---
# Module: Hardware - Tools
# Description: CLI and TUI tools for hardware management (Audio, Brightness, ACPI)
# Scope: System
# ---

{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    brightnessctl # Brightness (Fn keys)
    pamixer       # Volume CLI
    pulsemixer    # Volume TUI
    acpi          # Battery check
  ];
}

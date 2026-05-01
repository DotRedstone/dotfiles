# ---
# Module: Boot - Loader
# Description: Systemd-boot configuration and EFI settings
# Scope: System
# ---

{ ... }: {
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 5;
    consoleMode = "max";
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 1;
}

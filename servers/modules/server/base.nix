# ---
# Module: Server Base
# Description: Minimal locale, time, maintenance, and administration defaults for servers
# Scope: System
# ---

{ pkgs, ... }: {
  time.timeZone = "Asia/Shanghai";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  environment.systemPackages = with pkgs; [
    curl
    gitMinimal
    htop
    tmux
    vim
  ];

  services.fstrim.enable = true;
  zramSwap.enable = true;
}

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
    dnsutils
    fd
    gitMinimal
    htop
    jq
    lsof
    nftables
    nodejs
    pnpm
    python3
    ripgrep
    tmux
    vim
  ];

  services.fstrim.enable = true;
  zramSwap.enable = true;
}

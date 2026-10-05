# ---
# Module: User Maintenance
# Description: Automated cleanup for Home Manager generations, profiles, and temporary caches
# Scope: Home Manager
# ---

{ pkgs, ... }: {
  # [Generation Cleanup Service]
  systemd.user.services.home-manager-auto-expire = {
    Unit.Description = "Expire old Home Manager generations and user profile links";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.writeShellScript "expire-user-generations" ''
        set -eu
        if [ -d "$HOME/.local/state/nix/profiles" ]; then
          if [ -e "$HOME/.local/state/nix/profiles/home-manager" ]; then
            ${pkgs.nix}/bin/nix-env -p "$HOME/.local/state/nix/profiles/home-manager" --delete-generations +5 || true
          fi
          if [ -e "$HOME/.local/state/nix/profiles/profile" ]; then
            ${pkgs.nix}/bin/nix-env -p "$HOME/.local/state/nix/profiles/profile" --delete-generations +5 || true
          fi
        fi
        ${pkgs.nix}/bin/nix-collect-garbage --delete-older-than 14d || true
      ''}";
    };
  };

  # [Weekly Timer]
  systemd.user.timers.home-manager-auto-expire = {
    Unit.Description = "Weekly timer to expire old Home Manager generations";
    Timer = {
      OnCalendar = "weekly";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # [Temporary Retention Rules]
  systemd.user.tmpfiles.rules = [
    "d %h/.gemini/antigravity/browser_recordings 0700 - - 3d"
  ];
}

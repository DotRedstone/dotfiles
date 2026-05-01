# ---
# Module: Desktop - Polkit
# Description: Polkit authentication agent and user service
# Scope: System
# ---

{ pkgs, ... }: {
  environment.systemPackages = [ pkgs.polkit_gnome ];

  # [Polkit Agent Service]
  systemd.user.services.polkit-gnome-authentication-agent-1 = {
    description = "polkit-gnome-authentication-agent-1";
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };
}

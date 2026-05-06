# ---
# Module: ActivityWatch Services
# Description: Runs local ActivityWatch screen-time collection for Noctalia summaries
# Scope: Home Manager
# Notes:
# - ActivityWatch data is sensitive; do not add its data directory to persistence without a separate review.
# - Keep the server bound to 127.0.0.1 and do not enable browser watchers here.
# ---

{ pkgs, ... }: {
  home.packages = with pkgs; [
    activitywatch
    awatcher
  ];

  systemd.user.services.activitywatch-server = {
    Unit = {
      Description = "ActivityWatch local server";
      After = [ "graphical-session.target" ];
      StartLimitIntervalSec = 300;
      StartLimitBurst = 5;
    };

    Service = {
      ExecStart = "${pkgs.activitywatch}/bin/aw-server --host 127.0.0.1 --port 5600 --no-legacy-import";
      Restart = "on-failure";
      RestartSec = "10s";
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  systemd.user.services.awatcher = {
    Unit = {
      Description = "ActivityWatch Wayland window and AFK watcher";
      After = [ "graphical-session.target" "activitywatch-server.service" ];
      Wants = [ "activitywatch-server.service" ];
      StartLimitIntervalSec = 300;
      StartLimitBurst = 5;
    };

    Service = {
      ExecStart = "${pkgs.awatcher}/bin/awatcher --host 127.0.0.1 --port 5600 --idle-timeout 180";
      Restart = "on-failure";
      RestartSec = "10s";
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}

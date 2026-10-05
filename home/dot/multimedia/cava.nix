# ---
# Module: Cava
# Description: Console-based Audio Visualizer
# Scope: Home Manager
# ---

{ pkgs, ... }: {
  programs.cava = {
    enable = true;
    settings = {
      general = {
        # High-resolution bars
        framerate = 60;
        bars = 0; # Auto width
        bar_width = 2;
        bar_spacing = 1;
      };
      
      input = {
        method = "pipewire";
        source = "auto";
      };
      
      color = {
        theme = ''"noctalia"'';
      };
      
      smoothing = {
        integral = 77;
        monstercat = 1;
        waves = 0;
      };
    };
  };

  # Resolve activation conflict with existing regular file
  xdg.configFile."cava/config".force = true;

  # [Service]
  systemd.user.services.cava-bar = {
    Unit = {
      Description = "Cava audio visualizer bridge for status bar";
      After = [ "pipewire.service" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.writeShellScript "cava-bar-runner" ''
        set -eu
        mkdir -p /run/user/$UID/cava-bar
        cat << 'EOF' > /run/user/$UID/cava-bar/config
[general]
framerate = 30
bars = 6

[input]
method = pipewire
source = auto

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
bar_delimiter = 59
EOF
        exec ${pkgs.cava}/bin/cava -p /run/user/$UID/cava-bar/config | while IFS= read -r line; do
          printf '%s\n' "$line" > /dev/shm/cava_bars.tmp
          mv -f /dev/shm/cava_bars.tmp /dev/shm/cava_bars
        done
      ''}";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}

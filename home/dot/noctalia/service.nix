# ---
# Module: Noctalia User Service
# Description: Run Noctalia shell under the user systemd session
# Scope: Home Manager
# ---
# Notes:
# - Keep Niri startup responsible for compositor helpers only; systemd owns the shell lifetime.
# - ExecStartPre only removes Noctalia's runtime sockets, not user data or generated config.
# - Kill only the shell process on restart so apps launched through Noctalia are not torn down.

{ config, pkgs, ... }:
let
  noctaliaTraySync = pkgs.writeShellScript "noctalia-tray-sync" ''
    set -u

    noctalia="${config.programs.noctalia.package}/bin/noctalia"
    busctl="${pkgs.systemd}/bin/busctl"
    awk="${pkgs.gawk}/bin/awk"
    grep="${pkgs.gnugrep}/bin/grep"
    sleep="${pkgs.coreutils}/bin/sleep"
    seq="${pkgs.coreutils}/bin/seq"

    # [Wait for Noctalia IPC]
    for _ in $("$seq" 1 40); do
      "$noctalia" msg status >/dev/null 2>&1 && break
      "$sleep" 0.25
    done

    # [Wait for StatusNotifierWatcher DBus Object]
    for _ in $("$seq" 1 20); do
      "$busctl" --user status org.kde.StatusNotifierWatcher >/dev/null 2>&1 && break
      "$sleep" 0.25
    done

    # [Sync Pre-existing Tray Items]
    # Re-register existing StatusNotifierItem instances (e.g. WeChat, ChatGPT)
    # that do not re-register upon StatusNotifierWatcher restarts.
    for name in $("$busctl" --user list --no-legend 2>/dev/null | "$awk" '{print $1}' | "$grep" -E '^org\.(kde|freedesktop|ayatana)\.StatusNotifierItem-'); do
      "$busctl" --user call org.kde.StatusNotifierWatcher /StatusNotifierWatcher org.kde.StatusNotifierWatcher RegisterStatusNotifierItem s "$name" >/dev/null 2>&1 || true
    done
  '';
in
{
  systemd.user.services.noctalia = {
    Unit = {
      Description = "Noctalia shell";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      ExecStartPre = "${pkgs.coreutils}/bin/rm -f %t/noctalia-wayland-1.sock %t/noctalia-wayland-1.lock %t/noctalia-dmenu-wayland-1.sock";
      ExecStart = "${config.programs.noctalia.package}/bin/noctalia";
      ExecStartPost = [ "${noctaliaTraySync}" ];
      KillMode = "process";
      # Noctalia v5 can close its Wayland connection after a blocked plugin
      # refresh yet report a successful exit. Keep the desktop shell alive in
      # that case as well; an explicit `systemctl --user stop` still wins.
      Restart = "always";
      RestartSec = "2s";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}

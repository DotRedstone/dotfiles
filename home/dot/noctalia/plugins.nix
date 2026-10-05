# ---
# Module: Noctalia Plugins
# Description: Keep local Noctalia plugins available in the running shell
# Scope: Home Manager
# ---
# Notes:
# - Noctalia v5 stores enabled plugin sources in app-managed state, not plain config.
# - This startup sync is intentionally idempotent and only adds missing sources/plugins.

{ config, pkgs, ... }:

let
  noctaliaPluginSync = pkgs.writeShellScript "noctalia-plugin-sync" ''
    set -u

    noctalia="${config.programs.noctalia.package}/bin/noctalia"
    grep="${pkgs.gnugrep}/bin/grep"
    sleep="${pkgs.coreutils}/bin/sleep"
    seq="${pkgs.coreutils}/bin/seq"

    wait_for_ipc() {
      for _ in $("$seq" 1 40); do
        "$noctalia" msg status >/dev/null 2>&1 && return 0
        "$sleep" 0.25
      done
      return 1
    }

    ensure_source() {
      name="$1"
      kind="$2"
      location="$3"
      auto="''${4:-}"

      source_list="$("$noctalia" msg plugins source list 2>/dev/null || true)"
      printf '%s\n' "$source_list" | "$grep" -q "^''${name} " && return 0

      if [ -n "$auto" ]; then
        "$noctalia" msg plugins source add "$name" "$kind" "$location" "$auto" >/dev/null 2>&1 || true
      else
        "$noctalia" msg plugins source add "$name" "$kind" "$location" >/dev/null 2>&1 || true
      fi
    }

    ensure_plugin() {
      id="$1"

      plugin_list="$("$noctalia" msg plugins list 2>/dev/null || true)"
      printf '%s\n' "$plugin_list" | "$grep" -q "^''${id} .* enabled" && return 0
      "$noctalia" msg plugins enable "$id" >/dev/null 2>&1 || true
    }

    disable_plugin() {
      id="$1"

      plugin_list="$("$noctalia" msg plugins list 2>/dev/null || true)"
      printf '%s\n' "$plugin_list" | "$grep" -q "^''${id} .* enabled" && "$noctalia" msg plugins disable "$id" >/dev/null 2>&1 || true
    }

    wait_for_ipc || exit 0

    ensure_source official git https://github.com/noctalia-dev/official-plugins
    ensure_source community git https://github.com/noctalia-dev/community-plugins
    ensure_source dot path /home/dot/.dotfiles/home/dot/noctalia/plugins

    disable_plugin dot/sidebar
    disable_plugin dot/md3_dashboard
    disable_plugin teagar/niri-workspace-preview
    disable_plugin noctalia/screen_recorder
    disable_plugin fel/ocr

    # [Official Plugins]
    ensure_plugin noctalia/wallhaven
    ensure_plugin noctalia/timer
    ensure_plugin noctalia/translator
    ensure_plugin noctalia/bongocat
    ensure_plugin noctalia/wallpaper_depth
    ensure_plugin noctalia/notes

    # [Community Plugins]
    disable_plugin notoxus/media-island
    ensure_plugin aristides/udiskie
    ensure_plugin tordex/processes
    ensure_plugin tranzem/media-lyrics

    # [Local Plugins]
    ensure_plugin dot/gaming_power

    # [Translations Sync]
    trans_dir="/home/dot/.dotfiles/home/dot/noctalia/translations"
    overrides_dir="/home/dot/.dotfiles/home/dot/noctalia/overrides"
    target_dir="''${HOME}/.local/state/noctalia/plugins/materialized"
    if [ -d "$trans_dir" ]; then
      for f in $("${pkgs.findutils}/bin/find" "$trans_dir" -type f -name "zh-Hans.json" 2>/dev/null); do
        rel="''${f#$trans_dir/}"
        dest="''${target_dir}/''${rel}"
        "${pkgs.coreutils}/bin/mkdir" -p "$("${pkgs.coreutils}/bin/dirname" "$dest")"
        "${pkgs.coreutils}/bin/cp" -f "$f" "$dest"
      done
    fi
    if [ -d "$overrides_dir" ]; then
      for f in $("${pkgs.findutils}/bin/find" "$overrides_dir" -type f 2>/dev/null); do
        rel="''${f#$overrides_dir/}"
        dest="''${target_dir}/''${rel}"
        "${pkgs.coreutils}/bin/mkdir" -p "$("${pkgs.coreutils}/bin/dirname" "$dest")"
        "${pkgs.coreutils}/bin/cp" -f "$f" "$dest"
      done
    fi
  '';
in
{
  home.packages = with pkgs; [
    udiskie
    evtest
  ];

  systemd.user.services.noctalia.Service.ExecStartPost = [ "${noctaliaPluginSync}" ];
}

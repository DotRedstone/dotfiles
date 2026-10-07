# ---
# Module: Network - NetworkManager
# Description: NetworkManager enablement for wireless and wired connections
# Scope: System
# ---

{ pkgs, ... }:

let
  wiredManagementOnly = pkgs.writeShellScript "wired-management-only" ''
    set -eu

    interface="$1"
    event="$2"
    case "$event" in
      pre-up|up|dhcp4-change) ;;
      *) exit 0 ;;
    esac

    device_type="$(${pkgs.networkmanager}/bin/nmcli -g GENERAL.TYPE device show "$interface" 2>/dev/null || true)"
    [ "$device_type" = "ethernet" ] || exit 0

    uuid="''${CONNECTION_UUID:-}"
    if [ -z "$uuid" ]; then
      uuid="$(${pkgs.networkmanager}/bin/nmcli -g GENERAL.CON-UUID device show "$interface" 2>/dev/null || true)"
    fi
    case "$uuid" in
      ""|--) exit 0 ;;
    esac

    ${pkgs.networkmanager}/bin/nmcli connection modify uuid "$uuid" \
      ipv4.never-default yes ipv6.never-default yes \
      ipv4.route-metric 700 ipv6.route-metric 700

    if [ "$event" != "pre-up" ]; then
      ${pkgs.networkmanager}/bin/nmcli device reapply "$interface" || true
    fi
  '';
in
{
  networking.networkmanager = {
    enable = true;

    # Keep a direct cable to the router usable for recovery without allowing
    # that partially recovered network to replace the active Wi-Fi uplink.
    dispatcherScripts = [
      {
        type = "pre-up";
        source = wiredManagementOnly;
      }
      {
        type = "basic";
        source = wiredManagementOnly;
      }
    ];
  };
}

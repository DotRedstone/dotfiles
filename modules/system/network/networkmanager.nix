# ---
# Module: Network - NetworkManager
# Description: Enable NetworkManager 并将手机 USB 共享设为最高路由优先级
# Scope: System
# ---
# Notes:
# - 调试路由器时手机经 USB 共享提供外网，需保证其路由优先级高于 WiFi/有线。
# - 通过 dispatcher 在 USB 网络接口（enp0s20f0u*）激活时动态设置 metric=30，
#   同时写回连接 profile，避免换 USB 口/换手机生成新连接后 metric 回到默认。

{ pkgs, ... }:

{
  networking.networkmanager = {
    enable = true;

    dispatcherScripts = [
      {
        type = "basic";
        source = pkgs.writeShellScript "usb-tether-priority" ''
          # 手机 USB 共享（USB ethernet）激活时，设为最高路由优先级。
          iface="$1"
          action="$2"

          case "$action" in
            up|dhcp4-change)
              case "$iface" in
                enp0s20f0u*)
                  # 1) 持久化：写回连接 profile 的 metric，下次激活自动生效。
                  if [ -n "$CONNECTION_UUID" ]; then
                    nmcli connection modify uuid "$CONNECTION_UUID" ipv4.route-metric 30 2>/dev/null
                  fi
                  # 2) 立即生效：直接替换当前默认路由的 metric。
                  gw="$(ip -4 route show default dev "$iface" 2>/dev/null | awk '{print $3; exit}')"
                  if [ -n "$gw" ]; then
                    ip route replace default via "$gw" dev "$iface" metric 30 2>/dev/null
                  fi
                  ;;
              esac
              ;;
          esac
        '';
      }
    ];
  };
}

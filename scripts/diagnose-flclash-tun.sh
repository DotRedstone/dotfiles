#!/usr/bin/env bash
set -euo pipefail

section() {
  printf '\n===== %s =====\n' "$1"
}

run() {
  printf '\n$ %s\n' "$*"
  "$@" 2>&1 || true
}

run_sh() {
  printf '\n$ %s\n' "$1"
  bash -lc "$1" 2>&1 || true
}

have() {
  command -v "$1" >/dev/null 2>&1
}

sudo_n() {
  if have sudo && sudo -n true >/dev/null 2>&1; then
    sudo "$@"
  else
    printf 'sudo -n unavailable; skipped: sudo %s\n' "$*"
  fi
}

CONFIG="${HOME}/.local/share/com.follow.clash/config.yaml"
PREFS="${HOME}/.local/share/com.follow.clash/shared_preferences.json"

section "Context"
run date --iso-8601=seconds
run uname -a
run_sh "echo XDG_CURRENT_DESKTOP=\${XDG_CURRENT_DESKTOP-}; echo WAYLAND_DISPLAY=\${WAYLAND_DISPLAY-}; echo DESKTOP_SESSION=\${DESKTOP_SESSION-}"

section "FlClash Processes"
run_sh "ps -eo pid,user,comm,args | grep -Ei 'flclash|clash|mihomo' | grep -v grep"

section "Listening Ports"
run_sh "ss -lntup | grep -E '7890|7891|7892|9090|1053|FlClash|clash|mihomo' || true"

section "TUN Interfaces"
run_sh "ip -brief link | grep -Ei 'FlClash|tun|meta|clash|mihomo' || true"
run_sh "ip -4 addr show dev FlClash 2>/dev/null || true"
run_sh "ip -d link show dev FlClash 2>/dev/null || true"

section "Routes And Rules"
run ip rule
run_sh "ip route show table 2022 2>/dev/null || true"
run_sh "ip -4 route show table all | grep -E '198\\.18|2022|FlClash|tun|Meta|mihomo|clash' || true"
run_sh "ip route get 198.18.0.1 2>&1 || true"
run_sh "ip route get 1.1.1.1 2>&1 || true"

section "Kernel Network Flags"
run_sh "sysctl net.ipv4.ip_forward net.ipv4.conf.all.rp_filter net.ipv4.conf.default.rp_filter 2>/dev/null || true"
run_sh "sysctl net.ipv4.conf.FlClash.rp_filter net.ipv4.conf.FlClash.forwarding 2>/dev/null || true"

section "Firewall Snapshot"
run_sh "nix eval /home/dot/.dotfiles#nixosConfigurations.warden.config.networking.firewall.trustedInterfaces --json 2>/dev/null || true"
run_sh "sudo -n nft list ruleset 2>/dev/null | grep -nE 'FlClash|tun0|Meta|198\\.18|1053|7890|tproxy|redirect|redir|mark|iifname|oifname' | sed -n '1,220p' || true"
run_sh "sudo -n iptables-save 2>/dev/null | grep -Ei 'FlClash|tun0|Meta|198\\.18|1053|7890|TPROXY|REDIRECT|MARK' | sed -n '1,220p' || true"

section "DNS State"
run_sh "cat /etc/resolv.conf"
run_sh "resolvectl status 2>/dev/null | sed -n '1,180p' || true"
run_sh "nmcli dev show 2>/dev/null | grep -E 'GENERAL.DEVICE|IP4.DNS|IP6.DNS|DOMAIN|DNS' | sed -n '1,180p' || true"
run_sh "getent ahostsv4 ipinfo.io | sed -n '1,20p'"
if have dig; then
  run_sh "dig +time=2 +tries=1 +short ipinfo.io @127.0.0.1 -p 1053 2>/dev/null || true"
  run_sh "dig +time=2 +tries=1 +short ipinfo.io @10.0.0.1 2>/dev/null || true"
fi

section "Safe FlClash Config Summary"
if [[ -r "$CONFIG" ]]; then
  run_sh "grep -nE '^(mixed-port|port|socks-port|redir-port|tproxy-port|allow-lan|mode|log-level|ipv6|interface-name|routing-mark|find-process-mode):' '$CONFIG' || true"
  run_sh "awk '
    /^dns:/{in_dns=1; in_tun=0; print NR \":\" \$0; next}
    /^tun:/{in_tun=1; in_dns=0; print NR \":\" \$0; next}
    /^[^[:space:]][^:]*:/{if(in_dns||in_tun){in_dns=0; in_tun=0}}
    in_dns && /^[[:space:]]+(enable|listen|ipv6|enhanced-mode|fake-ip-range|default-nameserver|nameserver|fallback):/{print NR \":\" \$0}
    in_tun && /^[[:space:]]+(enable|device|stack|auto-route|strict-route|auto-detect-interface|dns-hijack|mtu|gso|route-address):/{print NR \":\" \$0}
  ' '$CONFIG'"
else
  printf 'config not readable: %s\n' "$CONFIG"
fi

if [[ -r "$PREFS" ]] && have jq; then
  section "Safe FlClash Preferences Summary"
  run_sh "jq -r '
    .[\"flutter.config\"]? // empty
    | fromjson?
    | {
        networkProps: {
          systemProxy: .networkProps.systemProxy,
          routeMode: .networkProps.routeMode,
          autoSetSystemDns: .networkProps.autoSetSystemDns,
          appendSystemDns: .networkProps.appendSystemDns
        },
        vpnProps: {
          enable: .vpnProps.enable,
          systemProxy: .vpnProps.systemProxy,
          dnsHijacking: .vpnProps.dnsHijacking,
          ipv6: .vpnProps.ipv6
        },
        patchClashConfig: {
          mixedPort: .patchClashConfig[\"mixed-port\"],
          port: .patchClashConfig.port,
          socksPort: .patchClashConfig[\"socks-port\"],
          redirPort: .patchClashConfig[\"redir-port\"],
          tproxyPort: .patchClashConfig[\"tproxy-port\"],
          dns: {
            enable: .patchClashConfig.dns.enable,
            listen: .patchClashConfig.dns.listen,
            enhancedMode: .patchClashConfig.dns[\"enhanced-mode\"],
            fakeIpRange: .patchClashConfig.dns[\"fake-ip-range\"]
          },
          tun: {
            enable: .patchClashConfig.tun.enable,
            device: .patchClashConfig.tun.device,
            stack: .patchClashConfig.tun.stack,
            autoRoute: .patchClashConfig.tun[\"auto-route\"],
            dnsHijack: .patchClashConfig.tun[\"dns-hijack\"]
          }
        }
      }
  ' '$PREFS'"
fi

section "Connectivity Tests"
run_sh "timeout 10 curl -4 --max-time 8 -v https://ipinfo.io/ip 2>&1 | sed -n '1,100p'"
run_sh "timeout 10 curl -4 --max-time 8 -v --interface FlClash https://ipinfo.io/ip 2>&1 | sed -n '1,100p'"
run_sh "timeout 10 curl -4 --max-time 8 -v -x http://127.0.0.1:7890 https://ipinfo.io/ip 2>&1 | sed -n '1,100p'"
run_sh "timeout 10 curl -4 --max-time 8 -v --resolve ipinfo.io:443:198.18.0.1 https://ipinfo.io/ip 2>&1 | sed -n '1,100p'"

section "Notes"
cat <<'EOF'
Paste the whole output back.
This script intentionally avoids dumping proxy groups, subscription URLs, tokens,
raw profile contents, and GUI cache databases.
EOF

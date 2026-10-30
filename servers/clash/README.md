# 路由器代理策略

`router-policy.json` 是现用路由器订阅的基础策略；`mobile-hotspot-policy.json` 属于独立的移动热点配置。路由器的实际 OpenClash 配置还会被其 UCI 设置覆写，修改 JSON 后须检查生成的 `/etc/openclash/config.yaml`。

## DNS 链路

LAN 客户端的普通 DNS 请求先到路由器 dnsmasq，再转给 Mihomo。路由器策略对普通域名使用经规则分流的境外 DoH，对中国域名使用境内 DoH；节点域名使用境内 DoH 引导连接，避免代理建立时的循环依赖。OpenClash 若启用“自定义 DNS”，其 `nameserver` 必须与本文件保持一致，并关闭追加 WAN DNS。LAN 的 UDP 与 TCP 53 都应重定向到路由器 dnsmasq。

验证时检查 OpenClash 生成配置中的 `nameserver`、`proxy-server-nameserver`、`nameserver-policy` 与 `respect-rules`，运行 `fw4 check`，并从 LAN 客户端分别执行 `dig @8.8.8.8 www.google.com` 和 `dig +tcp @8.8.8.8 www.google.com`。两者应得到 Mihomo Fake IP；再以 WAN 接口抓包确认测试期间没有 53 端口出站报文。应用自带 DoH、DoT 或 VPN 的流量不受 53 端口重定向约束。

变更路由器前备份 `/etc/openclash/config/config.yaml`、`/etc/config/openclash` 和 `/etc/config/firewall`；恢复时将这些文件复制回原路径，重启 OpenClash 并重载防火墙。

## IPv6 出口

路由器策略关闭了 Mihomo IPv6，因此路由器的 `wan6` 不应自动启动，防火墙也应拒绝 LAN 到 WAN 的 IPv6 转发。两项设置共同防止上游日后提供 IPv6 时客户端绕过代理。检查 `uci get network.wan6.auto` 为 `0`、`ip -6 route show default` 为空，并在 `nft list ruleset` 中确认 LAN IPv6 拒绝规则位于 LAN 到 WAN 的允许规则之前。若将来启用完整 IPv6 代理，应先验证 IPv6 DNS、路由与出口，再移除此保护。

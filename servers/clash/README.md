# 路由器代理策略

`router-policy.json` 是 Router 配置的基础策略；部署适配器同时从该策略生成 Device 配置。`mobile-hotspot-policy.json` 属于独立的移动热点配置。路由器的实际 OpenClash 配置还会被其 UCI 设置覆写，修改 JSON 后须检查生成的 `/etc/openclash/config.yaml`。

Cloudflare Worker 保留四个兼容配置键，但只有 Router 与 Device 两套有效配置：`root` = `router`，`desktop` = `mobile` = `device`。Device 仅覆盖本地监听、TUN、LAN 与端口设置，代理组、规则、provider 及 DNS 其他键保持 Router 内容。`servers/proxy-deployment/profiles/*.json` 与 `/u/` 交付属于 v2 金丝雀，不是权威配置。Router 的历史兼容基准来自 `edge-proxy-worker` 提交 `62915b2`；固定提交 `d407e15` 缺少原配置生成脚本，合并前仍须人工逐字节比较。

## DNS 链路

LAN 客户端的普通 DNS 请求先到路由器 dnsmasq，再转给 Mihomo。路由器策略对普通域名使用经规则分流的境外 DoH，对中国域名使用境内 DoH；节点域名使用境内 DoH 引导连接，避免代理建立时的循环依赖。OpenClash 若启用“自定义 DNS”，其 `nameserver` 必须与本文件保持一致，并关闭追加 WAN DNS。LAN 的 UDP 与 TCP 53 都应重定向到路由器 dnsmasq。

验证时检查 OpenClash 生成配置中的 `nameserver`、`proxy-server-nameserver`、`nameserver-policy` 与 `respect-rules`，运行 `fw4 check`，并从 LAN 客户端分别执行 `dig @8.8.8.8 www.google.com` 和 `dig +tcp @8.8.8.8 www.google.com`。两者应得到 Mihomo Fake IP；再以 WAN 接口抓包确认测试期间没有 53 端口出站报文。应用自带 DoH、DoT 或 VPN 的流量不受 53 端口重定向约束。

变更路由器前备份 `/etc/openclash/config/config.yaml`、`/etc/config/openclash` 和 `/etc/config/firewall`；恢复时将这些文件复制回原路径，重启 OpenClash 并重载防火墙。

## IPv6 出口

路由器策略关闭了 Mihomo IPv6，因此路由器的 `wan6` 不应自动启动，防火墙也应拒绝 LAN 到 WAN 的 IPv6 转发。两项设置共同防止上游日后提供 IPv6 时客户端绕过代理。检查 `uci get network.wan6.auto` 为 `0`、`ip -6 route show default` 为空，并在 `nft list ruleset` 中确认 LAN IPv6 拒绝规则位于 LAN 到 WAN 的允许规则之前。若将来启用完整 IPv6 代理，应先验证 IPv6 DNS、路由与出口，再移除此保护。

## 与路由器运行配置的对齐

`🧠 AI` 组的候选列表已于 2026-10-31 与路由器运行配置对齐（仅洛杉矶系列）；以路由器运行配置为准。

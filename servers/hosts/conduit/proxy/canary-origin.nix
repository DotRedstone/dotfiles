# ---
# Module: Conduit Canary Origin
# Description: 为 Conduit 添加隔离 canary 身份与回源证明入口
# Scope: Host
# Notes:
# - 仅在现有 CDN TLS 虚拟主机增加精确 /proof 路径；回源证明服务监听回环地址。
# - 部署前须核对旧 Xray 身份、Nginx 路由和目标主机的可用性。
# ---

{ config, edgeProxyWorker, lib, ... }: {
  dot.proxyAccounts.accounts.canary.enabled = lib.mkForce true;

  dot.services.proxyOriginProof = {
    enable = true;
    package = edgeProxyWorker;
    serverName = config.dot.services.xrayCdnWebSocket.serverName;
  };
}

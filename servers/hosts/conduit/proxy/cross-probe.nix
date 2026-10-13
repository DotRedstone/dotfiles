# ---
# Module: Conduit Cross Probe
# Description: 为 SG 回源候选预留洛杉矶探测器的独立 HTTPS 入口
# Scope: Host
# Notes:
# - 默认关闭；证书、SOPS 探测环境和 Worker 按 origin 路由尚未准备。
# ---

{ edgeProxyWorker, ... }: {
  dot.services.proxyPreferredProbe.package = edgeProxyWorker;
  dot.services.proxyProbeIngress.serverName = "probe-sg-v2-canary.bdot.in";
}

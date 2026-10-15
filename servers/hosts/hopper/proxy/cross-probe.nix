# ---
# Module: Hopper Cross Probe
# Description: 为 LA 回源候选预留新加坡探测器的独立 HTTPS 入口
# Scope: Host
# Notes:
# - 默认关闭；SOPS 探测环境与证书已备，公网入口和目标机运行态尚未验收。
# ---

{ edgeProxyWorker, ... }: {
  dot.services.proxyPreferredProbe.package = edgeProxyWorker;
  dot.services.proxyProbeIngress.serverName = "probe-la-v2-canary.bdot.in";
}

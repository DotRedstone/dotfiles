# ---
# Module: Hopper Cross Probe
# Description: 为 LA 回源候选预留新加坡探测器的独立 HTTPS 入口
# Scope: Host
# Notes:
# - 入口已在目标机验收；公网 DNS 与 Cloudflare 严格回源规则仍须独立发布。
# ---

{ edgeProxyWorker, ... }: {
  dot.services.proxyPreferredProbe.package = edgeProxyWorker;
  dot.services.proxyProbeIngress.enable = true;
  dot.services.proxyProbeIngress.optimizerMarker = "cf-opt-la-v1";
}

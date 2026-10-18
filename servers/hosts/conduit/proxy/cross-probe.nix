# ---
# Module: Conduit Cross Probe
# Description: 为 SG 回源候选预留洛杉矶探测器的独立 HTTPS 入口
# Scope: Host
# Notes:
# - 入口已在目标机验收；公网 DNS 与 Cloudflare 严格回源规则仍须独立发布。
# ---

{ edgeProxyWorker, ... }: {
  dot.services.proxyPreferredProbe.package = edgeProxyWorker;
  dot.services.proxyProbeIngress.enable = true;
  dot.services.proxyProbeIngress.optimizerMarker = "cf-opt-sg-v1";
}

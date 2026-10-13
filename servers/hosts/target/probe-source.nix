# ---
# Module: Target Preferred Probe Source
# Description: 为 Target 尚未启用的优选探测服务绑定锁定的 Worker 源码
# Scope: Host
# Notes:
# - 公网 HTTPS 入口、证书和探测运行时须另行审查。
# ---

{ edgeProxyWorker, ... }: {
  dot.services.proxyPreferredProbe.package = edgeProxyWorker;
}

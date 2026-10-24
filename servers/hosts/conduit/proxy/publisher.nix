# ---
# Module: Conduit Proxy Delivery Publisher
# Description: 在 Conduit 上定时发布隔离账户的已验证订阅
# Scope: Host
# Notes:
# - 两份 Geo 数据固定到上游提交与内容哈希；禁止将运行时密钥写入 Nix store。
# - 路由器两地优选池过期时发布器停止写入，保留交付 KV 的上次 manifest。
# ---

{ pkgs, ... }:

let
  geoRevision = "6a7865ed61619c1a6e6d246642018093f556c840";
  geoSite = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/${geoRevision}/geosite.dat";
    hash = "sha256-xST6HTrVQeujyy+j6k+PiZMfEBQ7rs0A1O9fTdVIBvQ=";
  };
  geoIp = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/${geoRevision}/geoip.metadb";
    hash = "sha256-C44/eYg9xalvMAwbyqH26Ybg6wM+uKXWU76QdaRkvT4=";
  };
in
{
  dot.services.proxyDeliveryPublisher = {
    enable = true;
    # 路由器按日小范围更新；容忍数次网络波动，超过一周仍停止发布。
    maxPoolAgeSeconds = 7 * 24 * 60 * 60;
    geoSitePath = toString geoSite;
    geoIpPath = toString geoIp;
  };
}

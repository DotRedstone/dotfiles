# 代理部署数据

本目录保存独立 `proxy-stack` Flake 所需的部署侧非密钥输入。新端点完成隔离测试和
审阅后才能发布；在此之前，现用的 `servers/proxy-accounts.json`、
`servers/clash/router-policy.json` 和订阅保持原有路径。

- `accounts.json` 的账户集合有意保持为空。现有账户仍由旧目录管理。迁移账户前，需核对
  `primaryOrigin`、两项批准的来源 ID、四种节点出口、生命周期元数据，以及分别
  存入 SOPS 的凭据。
- `nodes.json` 记录两处现有的公开节点端点和 Cloudflare 名称。REALITY 客户端参数
  与 WebSocket 路径属于私有运行时输入，不写入本文件。
- `preferred-sources.json` 登记路由器现用的两处独立 CloudflareST 来源。
  GitHub 来源需核对 owner、ref 和 path，并验证对应回源健康状态。
- `owned-domains.json` 仅保存直连规则所需的自有域名后缀和节点 IP。
- `profiles/` 分别保存路由器、桌面和移动端的网络行为。路由器配置保留现有的
  TUN、DNS、端口与控制器参数用于测试，尚未安装到路由器。

使用锁定版本编译器的 `validate` 命令检查本目录。生成的私有 YAML、token、
UUID、路径密钥与优选池快照不得进入 Git 或 Nix store。通用规则和编译器的
维护说明见独立项目 `/home/dot/Projects/proxy-stack/README.md`。

## 受限发布任务

`scripts/publish-core.mjs` 负责检查账户、来源和两地 v2 池，按账户输入生成稳定的
文档版本键，并预编译 router、desktop、mobile 配置及两份 CF provider。
`scripts/publish-runner.mjs` 从新版优选控制面的受限 HTTPS 接口读取
`sourceId × origin` 池，调用锁定的 `proxy-stack` 编译器，并对启用账户强制运行
Mihomo 静态检查。它先写五份不可变文档并逐项读回，最后单键写入
`delivery/manifest/v1`；无变化时跳过。失败时旧 manifest 保持可读，可能留下未被
引用的新文档。KV 最终一致，单键切换不代表全球客户端同时看到新版本。

`dot.services.proxyDeliveryPublisher` 是服务器侧默认关闭的 15 分钟 timer。只有在
锁文件的 `proxyStack` 修订与源码 NAR hash 匹配、隔离账户已登记、两地已验证池与
受限运行时完整、Mihomo Geo 数据可用时才可启用。它只应在一台指定主机运行，
`flock` 防止该主机重复执行；多主机并发发布需另行设计分布式协调。生产 `--apply`
拒绝空账户目录。`--check` 读取池和当前 manifest，但仅在内存模拟写入。

受限运行时由 SOPS 的 `proxy/delivery_runtime` 提供 JSON，包含
`version: 1`、`preferredReadToken`、每账户 `runtimeByAccount`，以及
`cloudflare.accountId`、`deliveryNamespaceId`、`apiToken`。每账户运行时包含独立
`deliveryToken`、`deliveryBaseUrl`、两地 UUID、REALITY 公钥与 short ID、WS 路径。
真实值只进入加密文件；目录和示例不记录其正文。控制面、交付 Worker 使用独立 KV，
旧 `clash/config/<profile>` 和旧优选池继续由既有 Worker 管理。

隔离测试使用确定修订的 `proxy-stack cd6663b` 与 `edge-proxy-worker 4fbe909`，
合成账户、内存 KV 和本机 Mihomo 数据文件；故障注入覆盖每份文档写入、读回、
manifest 写入、池版本混用、无变化跳过与跨账户键隔离。此测试不读取生产 KV，
也不证明 Cloudflare、两地回源或客户端更新已经生效。

## 回源证明与可信探测

`dot.services.proxyOriginProof` 与 `dot.services.proxyPreferredProbe` 均默认关闭。
前者在 Conduit/Hopper 各自回环地址运行，通过现有 CDN TLS 虚拟主机的专用
`/proof` 路径访问；Nginx 不注入证明令牌，请求方必须提供
`X-Origin-Proof-Token`。每地使用独立的 SOPS `proxy/origin_proof_key` 和
`proxy/origin_proof_token`，由 root 私有环境模板传给服务。后者默认只监听回环，
需要 SOPS `proxy/probe_env`、`proxy/probe_tls_cert` 和 `proxy/probe_tls_key`。
`probe_env` 内登记独立请求/响应 HMAC、明确允许的 Cloudflare 公网 CIDR、两地
`originId`、TLS 主机、专用路径和相应证明凭据。两模块的 `package` 选项须指向
固定 `edge-proxy-worker` 修订的源码包；当前项目尚未提供可跨主机取得的固定
发布物，启用前必须先解决该来源并核对散列。

probe 的公网 HTTPS 路由、证书信任、来源限制及新版 Worker 绑定需要单独审阅；
当前模块既不开放防火墙，也不覆盖旧代理路由。先在隔离环境验证错误证书、错误
nonce、错误 `originId`、错误 MAC、候选地址限制与失败保留，再分别执行两台
服务器的 `nixos-rebuild test` 并确认旧 Xray、SSH 与订阅正常。若新路径异常，
关闭相应新模块并恢复上一代系统配置；旧订阅、优选池与 Worker 不依赖这些模块。

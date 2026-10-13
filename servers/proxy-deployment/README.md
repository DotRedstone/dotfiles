# 代理部署数据

本目录保存独立 `proxy-stack` Flake 所需的部署侧非密钥输入。新端点完成隔离测试和
审阅后才能发布；在此之前，现用的 `servers/proxy-accounts.json`、
`servers/clash/router-policy.json` 和订阅保持原有路径。

- `accounts.json` 登记独立的 `canary` 测试账户；旧 `proxy-accounts.json` 中同名账户
  保持 disabled，现用账户不变。启用前需核对 `primaryOrigin`、两项批准的来源 ID、
  四种节点出口、生命周期元数据以及各自的 SOPS 凭据。
- `nodes.json` 记录两处现有的公开节点端点和 Cloudflare 名称。REALITY 客户端参数
  与 WebSocket 路径属于私有运行时输入，不写入本文件。
- `preferred-sources.json` 登记路由器现用的两处独立 CloudflareST 来源。
  `owner-campus-canary` 是两地 `signed-upload` 的隔离登记，尚无实测结果或已验证
  v2 池。GitHub 来源需核对 owner、ref 和 path，并验证对应回源健康状态。
- `owned-domains.json` 仅保存直连规则所需的自有域名后缀和节点 IP。
- `cloudflare-resources.json` 固定隔离灰度的两个 KV ID、各自的 binding、Worker
  名称与入口；这些是部署专属的公开标识，不包含令牌或私有运行时值。
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

受限运行时由 SOPS 的 `proxy/delivery_runtime` 提供 JSON；sops-nix 将其解密为
`root` 所有、`0400` 的运行时文件，发布任务直接读取该文件，不再次调用 `sops`。
JSON 包含 `version: 1`、`preferredReadToken`、每账户 `runtimeByAccount`，以及
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
需要 SOPS `proxy/probe_env`；默认从 SOPS `proxy/probe_tls_cert` 和
`proxy/probe_tls_key` 加载证书，Target 可选择运行时 ACME 证书路径。
`probe_env` 内登记独立请求/响应 HMAC、明确允许的 Cloudflare 公网 CIDR、两地
`originId`、TLS 主机、专用路径和相应证明凭据。两模块的 `package` 选项须指向
固定 `edge-proxy-worker` 修订的源码包。`servers/flake.nix` 的非 Flake 输入
`edgeProxyWorker` 已通过私有 Git SSH 来源锁定在 `306c249`，NAR 散列与原源码树
一致；Nix 的 `package` 选项接受其顶层 store 路径。Target 已单独传入此输入并
设置 `package`，但探测服务和 TLS 入口仍默认关闭。仅锁定和传入输入不会在远端
建立持久系统闭包或启动服务。

### Target 探测入口准备

`hosts/target/probe-tls.nix` 以 `dot.services.targetProbeTls.enable` 控制
DNS-01 证书和独立 HTTPS 入口，默认关闭。启用时从 SOPS
`proxy/probe_acme_dns_token` 读取 Cloudflare DNS API token，通过 ACME
DNS-01 为 `probe-v2-canary.dotdot.ggff.net` 申请证书；探测服务从
`/var/lib/acme/<domain>/fullchain.pem` 和 `key.pem` 读取证书，仅监听
`127.0.0.1:18444`。Nginx stream 在 443 透传 TLS，主机防火墙同时开放
TCP 443。证书申请未完成时，探测服务的 systemd 依赖使其启动失败；Nginx
仍可能监听 443，但不会提供有效探测响应。启用前须显式设置 ACME 联系邮箱、
接受 ACME 条款、核对已登记的 `proxy/probe_env`，并核对公网解析和腾讯云安全组。

Target 的 `proxy/probe_env` 已加密登记。四个变量为 `PROBE_REQUEST_KEY`、
`PROBE_RESPONSE_KEY`、`PROBE_ALLOWED_CIDRS_JSON` 和 `PROBE_ORIGINS_JSON`：
前两项与 Cloudflare canary 密文一致；后者为 LA/SG 各自的 TLS 主机、
`/proof` 路径、`la-origin` / `sg-origin` 身份和独立证明密钥、访问令牌。
候选范围取自 2026-10-13 的 [Cloudflare IPv4 列表](https://www.cloudflare.com/ips/)，
共 15 项，启用前须重新核对。轮换 HMAC 时须同步更新 Worker 与 Target；
轮换某地证明凭据时须同步更新该地服务与 Target，并确认旧凭据失效。
目前两地证明服务与新 Worker 均未启用，密文存在不代表验证链路可用。

DNS-01 token 应只授权 `dotdot.ggff.net` 单一区域的 Zone Read 与 DNS Edit；
该权限仍可修改此区域内的其他 DNS 记录，因此仅将 token 放在 Target 的
SOPS 密文中，以 root `0400` 运行时文件交给 ACME 单元。现有广域 Cloudflare
管理 token 不传给 Target。2026-10-13 创建的 `target-probe-dns01-2026-10-13`
token 只授予该 zone 的 Zone Read 与 DNS Write；只读 API 检查确认策略资源为
单一 zone，新 token 的 zone 列表也只返回 `dotdot.ggff.net`。Target 的 SSH
主机身份已能只读解密更新后的 SOPS 密文。未创建 DNS 记录或证书，也未启用服务。

轮换时先建立同范围的新 token，更新 Target SOPS 密文并只对隔离配置执行
`nixos-rebuild test`；确认 ACME 续期测试和 HTTPS 探测后再撤销旧 token。
若尚无到期证书，不以现有证书能提供 HTTPS 作为新 token 可续期的证据。
回退时关闭 `targetProbeTls` 并恢复前一代系统配置；旧 Worker、KV、订阅及
其他 Nginx stream 入口保持原路径。关联安全组与 443 放行须另行核对、变更和
回退，不由 Nix 模块控制。

`edge-worker-source.json` 与 `scripts/prepare-edge-source.mjs` 保留旧 `4fbe909`
归档路径作为回退，不属于新输入。该旧提交只在受限 legacy checkout 中，新的
`/home/dot/Projects/edge-proxy-worker` 克隆不包含它。需要复查旧归档时，先按
[旧 Worker 部署说明](../cloudflare/edge-worker/README.md) 确认受限 checkout，再运行：

```bash
node scripts/prepare-edge-source.mjs "$EDGE_PROXY_WORKER_LEGACY_REPOSITORY"
```

旧路径曾通过 Nix SSH 复制到 Conduit 与 Hopper 并核对 NAR 散列，但未被系统代际
或 GC root 引用，后续已被回收。启用新模块时应由实际系统闭包传输并持有新输入；
Hopper 的 ARM 构建路径继续遵循服务器迁移文档。不得只替换旧
`pinned-source.mjs` 的提交号：旧 `deploy.mjs` 仍调用新源码已移除的
`buildProfiles`。

## canary 凭据与启用门槛

`servers/secrets/conduit.yaml` 和 `hopper.yaml` 各自保存不同的
`xray/managed_canary_uuid`、`proxy/origin_proof_key` 和
`proxy/origin_proof_token`。`servers/secrets/cloudflare.yaml` 的 `canary`
分支保存独立交付令牌、订阅令牌、两地上传 HMAC、优选池读取令牌以及探测
请求/响应 HMAC；这些值未复制到通用项目或明文配置。仅登记密文不会改变
运行服务：旧 Xray 账户目录中的 `canary.enabled` 仍为 false。
两地主机当前的 SOPS 文件仍缺少 `proxy/delivery_runtime`；Target 已持有
`proxy/probe_env` 与 DNS-01 token，使用 ACME 证书路径而非 SOPS TLS 证书、私钥。
现有两份回源主机密文已经在对应主机上使用其
SSH 主机身份只读解密成功，但这不验证尚未写入的运行时字段或服务权限。

进入隔离灰度前，还需完成以下部署侧输入与实机证据：

1. 路由器在实际网络生成两地测量结果，经可信回源探测写入 `owner-campus-canary`
   的两个 v2 池；只有池格式和健康通过才允许发布。
2. 复核 Target 的 probe HTTPS 域名、证书申请、Cloudflare CIDR、DNS-only 解析
   和云安全组；核对两地证明服务与新版 Worker 的独立 KV 绑定，并确定私有交付域名。
3. 为指定发布主机准备完整 `proxy/delivery_runtime`，核对两地 UUID 与 SOPS
   一致，并更新当前仍有用户未提交改动的 `servers/flake.lock` 到已验编译器修订。
4. 在两台主机先用 `nixos-rebuild test` 验证 SSH、旧 Xray 身份、旧订阅和新 canary
   的 REALITY、CF TLS 回源；只对隔离客户端添加新配置，验证三平台交付、
   provider 更新与单账户撤销。旧 Worker、旧 KV 和路由器默认组继续保留。

这些条件目前未全部满足，未执行服务器、Cloudflare 或路由器切换。发生问题时
保持旧 manifest 与旧订阅，停用 canary 和新模块；如已执行 `nixos-rebuild test`，
恢复上一代系统配置并验证旧身份与 SSH。任何触及现用入口的切换需另行提交
可审查的 diff、实测证据和回退命令。

现有 LA/SG CDN 域名与各自 Nginx TLS 虚拟主机可承载独立的 proof 精确路径，
不要求修改旧 WS 路由。只读 Cloudflare 清单确认旧 `edge-proxy-next-state` KV、
`edge-proxy-next` 和 `edge-preferred-control` 仍存在。两个新版隔离 KV 已创建且
读回为空，ID 和预留 Worker 名称见 `cloudflare-resources.json`；新 Worker 尚未
部署，未设置路由。旧 KV 和旧 Worker 需作为回退保留，不能拿来存 v2
池或账户文档。probe 的公开 HTTPS 名称、证书与访问路由没有可核验的现成部署
绑定；现有 CDN 证书只声明给各自回源虚拟主机，不能推断适用于 probe API。

probe 的公网 HTTPS 路由、证书信任、来源限制及新版 Worker 绑定需要单独审阅；
当前模块既不开放防火墙，也不覆盖旧代理路由。先在隔离环境验证错误证书、错误
nonce、错误 `originId`、错误 MAC、候选地址限制与失败保留，再分别执行两台
服务器的 `nixos-rebuild test` 并确认旧 Xray、SSH 与订阅正常。若新路径异常，
关闭相应新模块并恢复上一代系统配置；旧订阅、优选池与 Worker 不依赖这些模块。

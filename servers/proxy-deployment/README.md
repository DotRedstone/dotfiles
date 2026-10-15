# 代理部署数据

本目录保存独立 `proxy-stack` Flake 所需的部署侧非密钥输入。新端点完成隔离测试和
审阅后才能发布；在此之前，现用的 `servers/proxy-accounts.json`、
`servers/clash/router-policy.json` 和订阅保持原有路径。

第 1 阶段的[代理源码独立候选](./stage1-proxy-only-review.md)只启用两地主机的
canary 与 `/proof`，不含 Hopper Gmail 现网基线。Conduit/Hopper 此前通过
临时 `test` 验收的是另一个**组合候选**，不能据此直接部署本候选到 Hopper。

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

历史隔离测试使用确定修订的 `proxy-stack cd6663b` 与旧 Worker `4fbe909`，
合成账户、内存 KV 和本机 Mihomo 数据文件；故障注入覆盖每份文档写入、读回、
manifest 写入、池版本混用、无变化跳过与跨账户键隔离。此测试不读取生产 KV，
也不证明 Cloudflare、两地回源或客户端更新已经生效。此隔离分支的 `proxyStack`
仍锁在 `23a64ff`，新版 Worker 输入锁在 `538d974`；这组锁定输入尚未
按上述历史组合完成联合运行验证。状态与发布阶段见[发布记录](../docs/proxy-stack-rollout.md)。

## 回源证明与可信探测

`proxyOriginProof` 与 `proxyPreferredProbe` 通用模块默认关闭；本候选在两地主机
覆盖启用 origin-proof。独立分支
`codex/cross-probe-isolated` 增加默认关闭的交叉探测入口和 DNS-01 证书选项。
方向、原 Worker 锁接口缺口、SOPS/TLS/DNS 前提与回退见
[交叉探测候选审查](./stage1-cross-probe-review.md)。
两地实机、Cloudflare、密钥与路由器的只读前置状态及逐阶段回退见
[v2 隔离发布前置核对](./stage1-live-readiness-review.md)。
两台组合候选临时验收后的系统持久化范围、逐机回退与启动项核对见
[双节点持久切换交接](./dual-node-persistence-handoff.md)。
两地 probe ingress 的离线候选身份、服务差异和逐机临时测试门槛见
[probe ingress 临时测试交接](./probe-ingress-temporary-test-handoff.md)。

每地 origin-proof 服务监听回环，Nginx 不注入 `X-Origin-Proof-Token`；请求方必须
提供对应令牌。两地主机分别以 SOPS 保存 `proxy/origin_proof_key` 与
`proxy/origin_proof_token`。交叉探测按被测回源地区命名：LA 候选由 Hopper 的
`probe-la-v2-canary.bdot.in/probe` 验证，SG 候选由 Conduit 的
`probe-sg-v2-canary.bdot.in/probe` 验证。两地复用现有 Nginx TCP 443，以独立
HTTPS 名称反代各自的回环探测服务，不增加公网端口。两台 SOPS 已有各自的
`proxy/probe_env` 与专用 TLS 证书／私钥；两个新名称仍缺公网 DNS 和逐名称
`strict` 规则，probe 与 ingress 均默认关闭。现有 CDN 回源证书的 SAN 只覆盖
各自旧名称，不能用于新入口。

独立 `edge-proxy-worker` 已发布 `PROBE_ENDPOINTS_JSON` v1 接口：
`origins.la` 固定指向 Hopper，`origins.sg` 固定指向 Conduit，两地请求／响应
HMAC 四把密钥互异。每台探测器的 `PROBE_ORIGINS_JSON` 只应包含对侧被测回源，
并与该地区 Worker 条目的 HMAC 及对侧 proof 凭据匹配。绑定缺失或探测失败时
保留旧池；接口格式见独立项目
[优选与交付接口](/home/dot/Projects/edge-proxy-worker/docs/preferred-v2.md)。
此隔离分支将 `servers/flake.lock` 的 `edgeProxyWorker` 单独锁到 `538d974`，
控制 Worker 具备双地区 `PROBE_ENDPOINTS_JSON` 契约。加密输入、Worker 和公网
入口的实况见下方[canary 凭据与启用门槛](#canary-凭据与启用门槛)；源码锁定
本身不证明隔离探测已可访问。

## v2 Worker 本地准备

`scripts/prepare-v2-workers.mjs` 从锁定的 Nix 源码读取两个新入口，从本目录
的目录数据和 `cloudflare-resources.json` 生成独立 KV 的 Wrangler 配置、源码修订记录及
secret 来源清单。配置只包含公开部署参数；`workers_dev` 关闭且不声明 Route。
`secret-references.json` 列出需在受限部署环境注入的密钥来源，不含明文。

```bash
cd /home/dot/.dotfiles
EDGE_PROXY_WORKER_CHECKOUT=/home/dot/Projects/edge-proxy-worker \
  node servers/proxy-deployment/scripts/prepare-v2-workers.mjs --dry-run
node servers/proxy-deployment/scripts/prepare-v2-workers.mjs \
  --out /path/to/private/output --account-id <32-hex-account-id>
```

dry run 核对 Worker 锁与 NAR hash，使用相同提交 checkout 的 Wrangler 分别打包
控制、交付入口，然后删除临时配置；不会读取 SOPS、写 KV 或访问 Cloudflare API。
每个 Wrangler 子进程最多等待 60 秒；超时会报错，不能把已打印的打包输出
视为双入口检查通过。脚本关闭 Wrangler banner 的在线版本检查和遥测，避免
本机 DNS 代理导致打包完成后进程仍等待网络；2026-10-16 两个锁定入口的
Wrangler dry run 均完成并返回 0。离线配置与独立 KV、secret 引用检查也通过。
`--out` 要求目标目录不存在，写入 `0600` 文件，供受限发布流程审阅；脚本不会
上传 secret 或部署 Worker。正式发布前仍需核对 SOPS 中已有的两地四把互异
HMAC 与 `PROBE_ENDPOINTS_JSON` 的运行绑定，从 canary 上传密钥组装 `SIGNING_KEYS_JSON`，
从发布账户令牌生成 `DELIVERY_TOKEN_HASHES_JSON`，并核对 `PREFERRED_READ_TOKEN`。
私有交付还依赖发布任务的 `proxy/delivery_runtime` 与 manifest；仅有打包成功
不能证明下载、探测或旧池保留在 Cloudflare 上生效。

### Target 历史探测预览（已废弃）

Target 将在到期后退役，`codex/target-probe-dryrun` 只保留为未合并、未部署的
历史预览，不再作为灰度路径。main 的 `hosts/target/probe-tls.nix` 与
`probe-source.nix` 仍默认关闭；Target 现网没有 ACME、probe 单元或 443 监听。
`servers/secrets/target.yaml` 中已加密登记 `proxy/probe_env` 与
`proxy/probe_acme_dns_token`，但运行时未加载。Cloudflare 的
`target-probe-dns01-2026-10-13` token 原为单一 zone 的 DNS-01 凭据，
`probe-v2-canary.dotdot.ggff.net` 尚无 DNS 记录。2026-10-13 的只读核对发现
该 token 可列出一个目标 zone，但现有管理凭据不能读取 token 详情或外部使用记录；
撤销前仍需确认没有仓库外消费者。本轮不撤销、不修改 SOPS 或主机配置。

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
运行服务：通用旧 Xray 账户目录中 `canary.enabled` 默认为 false；本代理候选
在两地主机层覆盖启用，实际激活仍取决于完整主机闭包。
两地主机 SOPS 已有各自的 `proxy/probe_env` 与静态 TLS 全链／私钥；
Conduit 已有 `proxy/delivery_runtime`，Hopper 尚无此项，发布主机归属仍需
核对。两份回源主机密文已用对应 SSH 主机身份只读解密成功。此前组合候选
已验收 proof 服务权限与真实回源；本独立代理候选未单独执行实机 `test`。
Target 的历史探测密文不迁作两地凭据；Cloudflare canary 密文已有双地区探测所需四把互异
HMAC 密钥。

执行 `node servers/proxy-deployment/scripts/check-probe-inputs.mjs` 可只读核对两台
环境与 Cloudflare 双地区配置、对侧 proof 凭据以及专用 TLS 的名称、私钥和
公开信任链；2026-10-16 本地检查通过。证书有效期至 2027-01-12，后续
需安排续期。Conduit 已在目标机受限临时目录验证 probe 输入与证书，过程见
[probe ingress 临时测试交接](./probe-ingress-temporary-test-handoff.md)；两地 probe
均未完成运行验收。

进入后续 v2 探测、交付与路由灰度前，还需完成以下部署侧输入与实机证据：

1. 路由器在实际网络生成两地测量结果，经可信回源探测写入 `owner-campus-canary`
   的两个 v2 池；只有池格式和健康通过才允许发布。
2. 复核两地独立 probe 名称、公开信任的 TLS 证书、Cloudflare 代理 DNS、
   来源限制及各自只含对侧回源的 SOPS 环境；核对新版 Worker 的
   `PROBE_ENDPOINTS_JSON`、proof 服务和独立 KV 绑定，并确定私有交付域名。
3. 为指定发布主机准备完整 `proxy/delivery_runtime`，核对两地 UUID 与 SOPS
   一致，并单独审阅将 `servers/flake.lock` 更新到已验编译器修订的差异。
4. 前阶段组合候选已临时 `test` 并验证两地 SSH、旧 Xray 身份、旧订阅和新 canary
   的 REALITY、CF TLS 回源；后续探测与交付配置仍需分别受控 `test`，只对隔离
   客户端添加新配置，验证三平台交付、provider 更新与单账户撤销。旧 Worker、
   旧 KV 和路由器默认组继续保留。

这些后续条件目前未全部满足。两地主机的第 1 阶段 rotation 组合候选已持久
`switch`。Conduit 的首次 probe ingress `test` 因上游证书链校验失败已回退，
修正候选仍待受控测试；Hopper 尚未测试。Cloudflare、DNS、路由器和 Target
未切换。发生问题时保持旧 manifest 与旧订阅，停用 canary 和新模块；如已执行
`nixos-rebuild test`，
恢复上一代系统配置并验证旧身份与 SSH。任何触及现用入口的切换需另行提交
可审查的 diff、实测证据和回退命令。

现有 LA/SG CDN 域名与各自 Nginx TLS 虚拟主机可承载独立的 proof 精确路径，
不要求修改旧 WS 路由。2026-10-16 的只读 Cloudflare 核对确认旧
`edge-proxy-next-state` KV、`edge-proxy-next` 和 `edge-preferred-control` 保留；
两个新版隔离 KV 均为 0 键；新版控制与交付 Worker 已部署，绑定各自 KV 和
所需 secret，但 `workers.dev` 均关闭，两个 probe 名称没有 DNS、Route 或
Custom Domain。资源 ID 与 Worker 名称见 `cloudflare-resources.json`。
旧 KV 和旧 Worker 需作为回退保留，不能拿来存 v2 池或账户文档。probe 的
公开 HTTPS 名称、证书与访问路由尚无实机部署；现有 CDN 证书只声明给各自
回源虚拟主机，不能推断适用于 probe API。

probe 的公网 HTTPS 路由、证书信任、来源限制及新版 Worker 绑定需要单独审阅；
交叉 probe 默认关闭时不开放新增防火墙端口，也不覆盖旧代理路由。先在隔离环境验证错误证书、错误
nonce、错误 `originId`、错误 MAC、候选地址限制与失败保留，再分别执行两台
服务器的 `nixos-rebuild test` 并确认旧 Xray、SSH 与订阅正常。若新路径异常，
关闭相应新模块并恢复上一代系统配置；旧订阅、优选池与 Worker 不依赖这些模块。

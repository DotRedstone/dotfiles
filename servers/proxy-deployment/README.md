# 代理部署数据

本目录保存独立 `proxy-stack` Flake 所需的公开目录结构与合成示例。新端点完成隔离测试和
审阅后才能发布；在此之前，现用的 `servers/proxy-accounts.json`、
`servers/clash/router-policy.json` 和订阅保持原有路径。
本目录交接记录中的 `example.test` 域名及大写资源标识是脱敏占位符，
不代表当前部署值；实际映射只从对应 SOPS 受限输入读取。
公开 HEAD、既有 main 与已推送历史的边界见[部署数据审计](./public-data-audit.md)。

第 1 阶段的[代理源码独立候选](./stage1-proxy-only-review.md)只启用两地主机的
canary 与 `/proof`，不含 Hopper Gmail 现网基线。Conduit/Hopper 此前通过
临时 `test` 验收的是另一个**组合候选**，不能据此直接部署本候选到 Hopper。

- `accounts.example.json` 展示合成账户结构；真实账户和来源映射保存在 Conduit
  的 SOPS `proxy/delivery_runtime.deploymentCatalog`。旧 `proxy-accounts.json` 中
  同名账户保持 disabled，现用账户不变。
- `nodes.json` 记录两处现有的公开节点端点和 Cloudflare 名称。REALITY 客户端参数
  与 WebSocket 路径属于私有运行时输入，不写入本文件。`nodes.example.json`
  使用文档专用地址和合成 origin ID；既有公开节点值的后续迁移见审计记录。
- `preferred-sources.example.json` 展示合成来源；实际来源清单保存在 Cloudflare
  SOPS 的 `canary.sources_json` 和 Conduit 受限运行时中。路由器已实测并上传
  两份 v2 池，结果见[控制 Worker 交接](./control-worker-canary-handoff.md)。
  GitHub 来源需核对 owner、ref 和 path，并验证对应回源健康状态。
- `owned-domains.json` 仅保存直连规则所需的自有域名后缀和节点 IP。
- `cloudflare-resources.example.json` 展示合成 Worker 资源。实际资源映射保存在
  Cloudflare SOPS 的 `canary.resources_json`；origin 与探测身份映射保存在
  `canary.origin_ids_json`，两地主机的探测名称映射保存在
  `canary.probe_hosts_json`，不进入公开目录。
- `profiles/` 分别保存路由器、桌面和移动端的网络行为。路由器配置保留现有的
  TUN、DNS、端口与控制器参数用于测试，尚未安装到路由器。

使用锁定版本编译器的 `validate` 命令检查由受限输入组装的目录；公开示例只用于
结构检查。生成的私有 YAML、token、
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
JSON 包含 `version: 1`、`preferredReadToken`、`preferredBaseUrl`、
`deploymentCatalog`、每账户 `runtimeByAccount`，以及
`cloudflare.accountId`、`deliveryNamespaceId`、`apiToken`。每账户运行时包含独立
`deliveryToken`、`deliveryBaseUrl`、两地 UUID、REALITY 公钥与 short ID、WS 路径。
真实值只进入加密文件；目录和示例不记录其正文。控制面、交付 Worker 使用独立 KV，
旧 `clash/config/<profile>` 和旧优选池继续由既有 Worker 管理。

历史隔离测试使用确定修订的 `proxy-stack cd6663b` 与旧 Worker `4fbe909`，
合成账户、内存 KV 和本机 Mihomo 数据文件；故障注入覆盖每份文档写入、读回、
manifest 写入、池版本混用、无变化跳过与跨账户键隔离。此测试不读取生产 KV，
也不证明 Cloudflare、两地回源或客户端更新已经生效。此隔离分支的 `proxyStack`
已锁在 `5393d0e`，新版 Worker 输入锁在 `052a959`；实际隔离发布见
[交付 Worker 交接](./delivery-worker-canary-handoff.md)。历史合成测试不等于
此次云端验收。状态与发布阶段见[发布记录](../docs/proxy-stack-rollout.md)。
独立 router 账号的两地身份、交付发布、出口验收与回退边界见
[生产账号交接](./router-production-handoff.md)。

## 回源证明与可信探测

`proxyOriginProof` 与 `proxyPreferredProbe` 通用模块默认关闭；两地主机已明确启用
origin-proof 和 probe ingress。独立分支
`codex/cross-probe-isolated` 增加默认关闭的交叉探测入口和 DNS-01 证书选项。
方向、原 Worker 锁接口缺口、SOPS/TLS/DNS 前提与回退见
[交叉探测候选审查](./stage1-cross-probe-review.md)。
两地实机、Cloudflare、密钥与路由器的只读前置状态及逐阶段回退见
[v2 隔离发布前置核对](./stage1-live-readiness-review.md)。
两台组合候选临时验收后的系统持久化范围、逐机回退与启动项核对见
[双节点持久切换交接](./dual-node-persistence-handoff.md)。
两地 probe ingress 的临时验收见
[临时测试交接](./probe-ingress-temporary-test-handoff.md)，持久切换状态和回退边界见
[持久切换交接](./probe-ingress-persistence-handoff.md)。

同一专用 HTTPS 虚拟主机还声明了供 `cf-optimizer` 使用的公开
`GET /probe/uncached?nonce=<32 位小写十六进制数>` 精确路径：

| 回源目标 | 主机 | `X-CF-Optimizer-Origin` |
| --- | --- | --- |
| `la` | Hopper 的 `host-1.example.test` | `cf-opt-la-v1` |
| `sg` | Conduit 的 `host-2.example.test` | `cf-opt-sg-v1` |

有效请求由 Nginx 直接返回 4096 字节静态正文、`Cache-Control: no-store,
max-age=0`，并原样回显 `X-CF-Optimizer-Nonce`。其他方法返回 405；缺失、
重复或格式错误的查询参数返回 400。`/probe` 的签名接口仍由原回环服务处理；
公开测速路径不提供可信回源证明。此处只声明源站行为，部署后仍须分别核对
两地 TLS/SNI、经 Cloudflare 的实际非缓存回源和 `cf-optimizer` 在接入网络上的
测量；响应头本身不能证明请求到达了目标源站。回退时撤销各主机
`cross-probe.nix` 中的 marker 配置并重新激活旧闭包，保留签名 `/probe`。

同一探针虚拟主机另以 SOPS 中的 `xray/cdn_speedtest_path` 挂载 8 MiB 下载正文，
供 `cf-optimizer` 对已入选候选测量实际下载速度。该路径只在目标机运行时解密，
不进入公开目录或 Nix store。入口仅接受带单个 32 位十六进制 nonce 的 GET，
回显 nonce 和该目标的 origin marker，设置 `no-store`，关闭压缩、分段响应和
该位置的访问日志。旧 Xray CDN 主机上的速测入口不变；下载测速仅在路由器的
root 专用目标路径文件安装后启用。上线时分别验收经候选 IP 直连的 TLS/SNI、
响应正文长度和缓存状态；本地构建不能证明公网请求已抵达源站。
本轮生产部署的测速结果未通过运行验收，当前暂停发布与回退边界见
[优选下载测速部署交接](./download-speed-rollout-handoff.md)。

每地 origin-proof 服务监听回环，Nginx 不注入 `X-Origin-Proof-Token`；请求方必须
提供对应令牌。两地主机分别以 SOPS 保存 `proxy/origin_proof_key` 与
`proxy/origin_proof_token`。交叉探测按被测回源地区命名：LA 候选由 Hopper 的
`host-1.example.test/probe` 验证，SG 候选由 Conduit 的
`host-2.example.test/probe` 验证。两地复用现有 Nginx TCP 443，以独立
HTTPS 名称反代各自的回环探测服务，不增加公网端口。两台 SOPS 已有各自的
`proxy/probe_env` 与专用 TLS 证书／私钥；两地主机已启用 probe 与 ingress。
`bdot.in` 的两个精确 probe hostname Configuration Rules 已创建，
`action_parameters.ssl` 均为 `strict`，zone 默认仍为 `flexible`。2026-10-16
新增两条 proxied A：`host-1.example.test` 指向 Hopper
`140.245.62.36`（记录 ID `15c9ca4f22287430e5c790f68ce72f9c`）；
`host-2.example.test` 指向 Conduit `107.174.1.97`（记录 ID
`97b0e18c9b1bdf92c9c3b6e11d07505b`）。原有 `bdot.in/*` Worker Route 未改。
现有 CDN 回源证书的 SAN 只覆盖
各自旧名称，不能用于新入口。

两条记录的权威 NS 查询返回 Cloudflare IP。两地经 Cloudflare HTTPS 对新 probe
入口发送签名请求均返回 200，响应 HMAC 正确；错误签名、过期时间戳、越界地址
分别返回 404、404、422，无签名 GET 返回 404，TLS 校验错误为 0。该验收覆盖
当前公网入口；规则配置与 HTTPS 结果不能单独证明后续 Worker 调度、路由器测量
或交付已运行。

独立 `edge-proxy-worker` 已发布 `PROBE_ENDPOINTS_JSON` v1 接口：
`origins.la` 固定指向 Hopper，`origins.sg` 固定指向 Conduit，两地请求／响应
HMAC 四把密钥互异。每台探测器的 `PROBE_ORIGINS_JSON` 只应包含对侧被测回源，
并与该地区 Worker 条目的 HMAC 及对侧 proof 凭据匹配。绑定缺失或探测失败时
保留旧池；接口格式见独立项目
[优选与交付接口](/home/dot/Projects/edge-proxy-worker/docs/preferred-v2.md)。
此隔离分支将 `servers/flake.lock` 的 `edgeProxyWorker` 锁到 `052a959`，
控制 Worker 具备双地区 `PROBE_ENDPOINTS_JSON` 契约。公网控制入口、绑定、
两地已验证池与实机验收见[控制 Worker 隔离发布交接](./control-worker-canary-handoff.md)。

## v2 Worker 本地准备

`scripts/prepare-v2-workers.mjs` 从锁定的 Nix 源码读取两个新入口；正式准备时
从 SOPS 读取受限 Worker 资源与来源，`--dry-run` 使用本目录的合成示例。
脚本生成独立 KV 的 Wrangler 配置、源码修订记录及 secret 来源清单。输出目录
仅供受限部署使用；`workers_dev` 关闭，交付入口使用
独立 Custom Domain，控制入口由受限部署配置绑定独立 Custom Domain。
`secret-references.json` 列出需在受限部署环境注入的密钥来源，不含明文。
编译器换版时，`--alternate-compiler-revision <旧 SHA>` 为交付 Worker 临时生成
`ALTERNATE_COMPILER_REVISION`；先部署可接受新旧修订的 Worker，核对旧 manifest
仍可下载，再切换发布器并发布新 manifest。验收三类账户和 provider 后重新生成
仅接受新修订的配置。两个 SHA 必须是不同的完整提交，过渡绑定只保留到切换验收。

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
`host-3.example.test` 尚无 DNS 记录。2026-10-13 的只读核对发现
该 token 可列出一个目标 zone，但现有管理凭据不能读取 token 详情或外部使用记录；
撤销前仍需确认没有仓库外消费者；本次代理部署数据脱敏不修改 Target 的
SOPS 项或主机配置。

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
Conduit 已有 JSON 格式的 `proxy/delivery_runtime` 并作为指定发布主机；
Hopper 无此项。两份回源主机密文已用对应 SSH 主机身份只读解密成功。此前组合候选
已验收 proof 服务权限与真实回源；本独立代理候选未单独执行实机 `test`。
Target 的历史探测密文不迁作两地凭据；Cloudflare canary 密文已有双地区探测所需四把互异
HMAC 密钥。

执行 `node servers/proxy-deployment/scripts/check-probe-inputs.mjs` 可只读核对两台
环境与 Cloudflare 双地区配置、对侧 proof 凭据以及专用 TLS 的名称、私钥和
公开信任链；2026-10-16 本地检查通过。证书有效期至 2027-01-12，后续
需安排续期。Conduit 已在目标机受限临时目录验证 probe 输入与证书，过程见
[probe ingress 临时测试交接](./probe-ingress-temporary-test-handoff.md)；两地 probe
均已完成此前的临时验收和持久切换。2026-10-16 新增公开测速入口与轮换后的
回源 proof 凭据也已逐机持久切换；实时测量和池写入见
[控制 Worker 交接](./control-worker-canary-handoff.md)。两台尚未重启。

进入后续 v2 探测、交付与路由灰度前，还需完成以下部署侧输入与实机证据：

1. 两地直连测量、跨地证明与隔离 v2 池已验收；路由器已安装故障关闭的出口
   校验并自动错峰刷新。代理规则后续重载时仍须确认 `nobody` 直连规则，
   旧池与旧 CloudflareST 保留可回退。
2. 两地独立 probe 名称、TLS、代理 DNS、SOPS 环境、proof 服务、控制与交付
   Worker 绑定已核对；交付域名和隔离 KV 的实测见
   [交付 Worker 交接](./delivery-worker-canary-handoff.md)。
3. Conduit 的 `proxy/delivery_runtime` 已核对，发布 timer 已持久启用，手动
   触发与首次自动触发均通过；路由器定时刷新已实测。
4. 前阶段组合候选已验证两地 SSH、旧 Xray 身份、旧订阅和新 canary
   的 REALITY、CF TLS 回源；隔离 Mihomo 进程已验证四类出口。后续只对隔离
   客户端添加新配置，验证三平台长期导入、provider 更新与单账户撤销。旧 Worker、
   旧 KV 和路由器默认组继续保留。

这些后续条件目前未全部满足。两地主机的第 1 阶段 rotation、私有 probe ingress
及新增公开测速入口均已持久切换；新 probe DNS 和两地路由器直连测量已通过
隔离验收。Target 与路由器默认代理组未切换。发生问题时保留旧 manifest、
旧订阅和旧 Worker；不要恢复已轮换的 origin proof 凭据。任何触及现用入口的
切换需另行提交
可审查的 diff、实测证据和回退命令。

现有 LA/SG CDN 域名与各自 Nginx TLS 虚拟主机可承载独立的 proof 精确路径，
不要求修改旧 WS 路由。2026-10-16 的只读 Cloudflare 核对确认旧
`edge-proxy-next-state` KV、`edge-proxy-next` 和 `edge-preferred-control` 保留；
新版控制 KV 已有两地隔离池，交付 KV 已有 canary manifest；新版控制与交付
Worker 已部署，绑定各自 KV 和
所需 secret，`workers.dev` 均关闭。两个 probe 名称已有上述 DNS；控制 Worker
和交付 Worker 已添加各自的独立 Custom Domain。资源 ID 与 Worker 名称见
Cloudflare SOPS `canary.resources_json`，控制入口的实测状态见
[控制 Worker 隔离发布交接](./control-worker-canary-handoff.md)，交付入口见
[交付 Worker 交接](./delivery-worker-canary-handoff.md)。
旧 KV 和旧 Worker 需作为回退保留，不能拿来存 v2 池或账户文档。probe 的
源站 HTTPS 入口与公开测速路径已在两台主机持久切换并通过实机验收；
系统 profile 与默认启动项均为新候选，尚未重启。probe 使用各自独立证书，不能复用
现有 CDN 证书的适用性判断。

后续仍需安排静态证书续期和客户端验收。交叉 probe 不开放新增
防火墙端口，也不覆盖旧代理路由。新路径异常时停用隔离上传并保留上次有效池，
验证旧 Xray、SSH 与订阅；不得用含旧 proof 凭据的闭包作为日常回退目标。

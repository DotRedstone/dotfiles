# 双节点代理分阶段发布记录

本页保留 2026-10-11 的本地验证记录，并记录 2026-10-13 的交接状态；它不是
现网发布令。2026-10-13 Conduit/Hopper 曾用含 Hopper Gmail 基线的组合候选完成
临时 `test`；2026-10-14 另整理出仅含代理行为的
[源码候选](../proxy-deployment/stage1-proxy-only-review.md)，其 Hopper 整机闭包未经
批准直接激活。路由器和现用 Cloudflare Worker 未切换到新链路。
2026-10-14 的独立[Worker 锁与适配候选](../proxy-deployment/stage1-cross-probe-review.md#后续-worker-锁与本地适配候选)
已将本分支的 `edgeProxyWorker` 锁更新到 `538d974`；下表仍记录 2026-10-13
基线，不代表本分支的最新锁。

## 2026-10-13 灰度前基线

| 层级 | 已确认状态 | 待验证边界 |
| --- | --- | --- |
| 独立源码与锁 | `proxy-stack` main 为 `cd6663b`、脱敏 v2 分支为 `4179daf`，服务器已提交锁仍为 `23a64ff`；`edge-proxy-worker` main 为 `538d974`，服务器已提交的非 Flake 输入仍锁 `306c249` | 新接口尚未更新到服务器锁；远端构建需核对私有仓库读取权限 |
| main 声明 | Conduit/Hopper 的旧账户与订阅仍在，canary 在旧账户目录中关闭；两地 origin-proof 与通用 probe 模块默认关闭。Target 的默认关闭探测声明属于已废弃的历史准备 | 声明与密文存在不代表服务已部署 |
| 独立预览 | `codex/target-probe-dryrun` 未合并且不再推进；`codex/origin-canary-dryrun` 另有默认关闭的交叉探测入口，未纳入本代理候选 | 后者的合成启用求值不等同于两地主机实际探测服务验收 |
| Cloudflare | 两个隔离 KV 于 2026-10-13 查询均为 0 键；Target DNS-01 token 留在加密 SOPS 中，新版控制与交付 Worker 尚未部署 | Target 旧 probe 与两地新 probe 名称均无 DNS 记录；证书、Worker 绑定与 v2 池未验收，旧 Worker/KV 保留 |
| 现网 | Conduit/Hopper 的 Xray、Nginx 和旧 `managed:guest` 身份继续运行；Target 无 443、ACME 或 probe 运行单元。路由器 LuCI/Zashboard 已只读取得 34 个组的 `now` | UI 选组不证明真实出口、两地回源和应用流量；新探测服务未运行 |

Target 将在到期后退役，双节点 v2 探测改由两地交叉承担。部署输入、预览分支与
回退边界以[部署目录](../proxy-deployment/README.md)为准；新版 Worker 的
`PROBE_ENDPOINTS_JSON` 接口见独立项目
[优选与交付接口](/home/dot/Projects/edge-proxy-worker/docs/preferred-v2.md)。该接口已在独立项目发布；本分支已锁定源码，尚未部署。

## 组件契约与发布物

下表是部署侧的责任边界。跨项目接口的字段、版本兼容期和确定修订须由各项目定版；
新账户须经隔离验证后才能进入现网。

| 所有者 | 输入与接口 | 发布物 | 部署侧责任 |
| --- | --- | --- | --- |
| `proxy-stack` | 版本化账户、节点、来源和客户端 profile；私有凭据引用 | Mihomo 配置编译器、规则模型、Xray Nix 模块 | 锁定修订，使用合成身份做跨仓库契约检查 |
| `cf-optimizer` | 每个来源及回源地区的测速任务；受限上传凭据 | 带来源、实测网络、时间和质量指标的版本化结果；桌面 CLI、路由器后端与 LuCI | 登记批准来源，保留旧任务及最后有效池，核对真实网络测速 |
| `edge-proxy-worker` | 经批准的优选结果、已编译的私有配置包、Worker secret 和绑定 | 优选控制、配置交付与可选代理出口 Worker | 固定源码提交与部署参数，使用新名称和路由灰度，保留旧 Worker |
| 本仓库 `servers/` | 上述确定修订与接口、真实账户和端点、SOPS 引用 | 两台服务器配置、私有发布输入、路由器适配与回滚记录 | 不复制通用程序；只发布已验收的账户、来源和入口 |

`proxy-stack` 中现存的 Worker bundle 与 `edge-proxy-worker` 的运行时所有权有重叠。
两项目应先确定配置数据的唯一编译入口和 Worker 运行时的唯一源码，再由部署仓库
锁定兼容的修订；不能只凭构建成功推断两者的接口可互换。

`proxy-stack` 曾在修订 `4643491` 固定这条边界，其主要接口见该项目的
`docs/contracts.md`、`schema/measurement.schema.json`、`schema/pool-v2.schema.json`
和 `schema/delivery-manifest.schema.json`。部署侧在受限环境使用同一固定编译器，
为每个账户预编译 router、desktop、mobile 三份配置及 `la-cf`、`sg-cf` 两份
provider。发布时先写入五份不可变私有文档并验证，再切换 manifest；Worker 按账户
令牌及 manifest 授权，原样返回文档，不在请求时编译或改写规则。每账户独立令牌和
两台 Xray 身份由 SOPS 与受限运行时提供，生成文件及令牌不得进入 Git 或 Nix store。

main 的 `servers/flake.lock` 仍指向 `proxy-stack 23a64ff`，工作区另有任务外
未提交的锁文件改动；旧 `edge-worker` 部署适配仍使用四份 profile KV 键，
并从受限归档读取 `4fbe909`。截至 2026-10-13，服务器仍锁
`306c249`；此隔离分支已单独锁定 `538d974`，这是另一条输入，
不能直接替换旧适配器的提交。旧 KV、订阅与 Worker 保持原有路径。

部署仓库已增加默认关闭的发布 timer、回源证明与可信探测模块。历史合成检查用
`proxy-stack cd6663b` 和 `edge-proxy-worker 4fbe909` 完成合成账户的跨仓库检查：
三平台配置通过 Mihomo 静态检查，五份文档经内存 KV 由 Worker 原样交付，
故障注入保持旧 manifest 可读。这不是当前两项 Flake 锁定输入的联合运行测试；
`servers/flake.lock` 中的 `proxyStack` 仍是旧修订，
`servers/cloudflare/edge-worker/scripts/deploy.mjs` 仍调用旧固定 Worker 的
`buildProfiles`；升级必须同时改造该适配器，不能仅替换固定提交。
受限任务的输入、SOPS 键和隔离验收见 [部署目录](../proxy-deployment/README.md)。
通用模块默认关闭；本代理候选只在两地主机覆盖启用 canary 与 `/proof`。
两地 UUID、证明凭据与控制令牌仍只保存在 SOPS 密文中。未生成真实 v2 池，
未发布私有文档或改变路由器、Worker 默认路径。

## 本地变更

- 独立 `proxy-stack` Git/Flake 提供 11 个 Mihomo 策略组、按账户地区优先的两地
  CF fallback、两条手动 REALITY、受授权的手动 Worker、规则与配置编译器。
- Xray 模块从本地服务目录抽出为锁定 input；两台海外主机从部署侧传入旧账户目录，
  SOPS secret 名称、入站端口和旧身份保持原样。`target` 与 `gcp-free` 仍使用旧模块。
- 部署侧新增非秘密的账户、节点、来源、自有域名和三类客户端 profile 目录。
  新目录的 canary 仍只完成预备登记，两地主机的隔离身份另由上述代理候选启用；
  旧 `proxy-accounts.json`、旧订阅、旧 Worker
  和路由器配置保留。
- 三种 Worker 的独立 bundle 可从 `servers#proxyStackWorkerBundles` 的锁定修订构建。
  配置 Worker、优选控制 Worker 和参数化 CFST 脚本均未安装；独立 Worker 项目
  已在本地实现两地探测绑定，但部署侧尚未锁定该修订或完成运行验收。

`servers/flake.nix` 通过私有 GitHub 仓库引入 `proxy-stack`，`flake.lock` 固定提交。
构建端须有该私有仓库读取权限；本机曾通过 Git HTTPS 认证确认可读，远端读取
能力仍须在部署前核对。

## 历史本地验证与当前检查

下列是 2026-10-11 的本地验证结果，不代表当前锁与新源码已完成联合验收：

```text
proxy-stack: node --test test/*.test.mjs                 10/10 通过
proxy-stack: nix flake check path:.                      x86_64 通过
proxy-stack: sh -n + shellcheck router/run-cfst.sh      通过
部署目录: proxy-stack validate                           通过
测试身份: router/desktop/mobile 的 mihomo -t             3/3 通过
servers: nix flake check path:./servers --no-build      四主机求值通过
servers: nix build path:./servers#proxyStackWorkerBundles --no-link  三 bundle 构建通过
```

接口定版修订 `4643491` 的后续合成检查：对本目录执行 `node src/cli.mjs validate`
通过；`test/render-deployment-fixture.mjs` 用合成凭据与池生成 router、desktop、mobile
三份配置及两地 CF provider；三份 `mihomo -t` 均通过。检查在自动清理的临时目录
运行，复用了本机已有 GeoSite/GeoIP 数据以避免在线下载。它仍未测试 Worker 的
manifest 鉴权或私有文档交付；main 的 Flake 锁也未更新到该修订。

2026-10-13 重新执行 `nix flake check path:./servers --all-systems --option substituters ''`
通过四主机求值和两架构 Worker bundle 的 derivation 检查。
此前 Hopper/Hermes 的无效 store source 曾使完整检查失败；该错误本轮未复现，
源路径现已可读。此结果未构建 Hopper 系统或 ARM Worker bundle，也不证明
远端服务可用。

以上 2026-10-11 的本地结果只证明语法、引用与构建。后续组合候选另完成两地
旧身份、新 canary 的直连/旧 CDN WS 实际出口及 `/proof` 验证；应用登录、大文件、
订阅刷新和单账户撤销仍未验收。历史核对中路由器只读 SSH 拒绝所用密钥、
Controller 返回 401；2026-10-13 后续通过已登录 LuCI/Zashboard 只读取得活动
配置元数据和 34 个组的 `now`，脱敏基线保存在 Git 外。UI 状态仍不足以允许切换默认组。

## 发布前检查与回滚

1. **锁与身份准备**：确认远程构建端的私有仓库读取权限；核对 SOPS 中已有的两台
   canary UUID、订阅令牌与证明凭据，并补齐发布所需的 REALITY 客户端参数与
   WebSocket 路径。构建端只能读锁定修订。
   回滚：将 `proxyStack` 锁回前一已验修订；首次引入时撤销 input 并恢复旧模块导入。
2. **受限灰度**：先在两台服务器 `nixos-rebuild test`，保持现有 SSH 会话与旧订阅；
   核对 Xray 监听、旧账户继续可用、测试账户两地 REALITY 和 CF 回源。受信任探测
   服务、私有 bundle 和 Worker 绑定通过测试后，使用新的 Worker 名称与路由发布，
   不覆盖旧 `/clash/`、`/sub/`。回滚：恢复服务器上一代配置并停用新路由/Worker；
   旧 Worker、订阅和旧 Xray 身份仍可使用。
3. **来源与路由器**：用签名上传和批准的 GitHub 路径各测一地成功/失败保留；
   先记录路由器所有相关组的 `now` 和活动配置带时间戳的副本，再添加新订阅。
   验证真实 Google、X、Telegram、ChatGPT、开发下载、YouTube 播放和 Minecraft
   登录/令牌刷新/进服，最后才把 `🚀 主线路` 选到两地优选。回滚：恢复旧订阅与
   配置备份、原策略组选项；读取运行时 `now`，确认出口与 DNS 恢复。

后续涉及 Cloudflare Worker/DNS、主机服务或路由器的发布步骤，须先附具体 diff、
目标、访问方式、影响面与回滚命令，再分别审阅与执行。

## 阶段验收条件

| 阶段 | 进入下一阶段前的证据 | 失败时的保留与回退 |
| --- | --- | --- |
| 基线 | 保存旧订阅、定时任务、测速脚本、优选池与 Mihomo 各组运行时 `now` 的脱敏摘要；核对两台 Xray、Worker 和 EasyTier 的实际状态 | 未取得的实机证据标为未知；不改变旧链路 |
| 接口定版 | 记录 `proxy-stack`、`cf-optimizer`、`edge-proxy-worker` 的修订、schema 版本、输入输出及兼容期；合成账户和来源通过跨仓库检查 | 保持当前锁和已登记但未发布的 canary 目录，不发布不兼容产物 |
| 本地隔离 | router、desktop、mobile 完整配置均通过 `validate` 与 `mihomo -t`；两节点 Nix 求值通过，私有内容不进入 Git 或 Nix store | 删除临时生成物；旧配置与旧订阅继续运行 |
| 单账户灰度 | 两台服务器各自验证 REALITY 与 CF TLS 回源、旧身份持续可用；新账户的订阅更新、撤销、DNS 和应用流量经实机验证 | `nixos-rebuild test` 回退到上一代；停用新账户入口，保留旧身份 |
| 优选来源 | 校验签名与批准仓库的来源隔离、回源健康、失败保留和过期处理；路由器测速进程正常退出且不停止 OpenClash | 不替换旧定时任务；恢复上一份有效池 |
| 路由切换 | 先保存活动配置和每个相关组的 `now`，再验证两地实际出口、YouTube 与 Minecraft 登录、下载及 DNS；切换后重新读取 `now` | 恢复配置备份及旧 provider 选择，复核出口与 DNS |

构建、语法检查、KV 中存在结果和服务处于 active 只覆盖各自层级；它们不能替代
单账户撤销、真实回源、客户端选组与应用流量的验收。旧订阅、旧定时任务与旧 Worker
至少保留到新链路完成对应实机验收。

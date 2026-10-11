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

`edge-worker-source.json` 固定 `edge-proxy-worker 4fbe909` 的完整提交和归档
NAR 散列。`node scripts/prepare-edge-source.mjs /home/dot/Projects/edge-proxy-worker`
会从该提交归档、核对散列并加入本机 Nix store；它不读取工作树的未提交文件。
独立 Worker 项目目前没有远端，另一台机器无法仅凭 dotfiles 重建源码包。
一次性的隔离验证可由工作站通过现有 Nix SSH 传输链复制该固定 store 路径：

```bash
edge_source_store=$(node scripts/prepare-edge-source.mjs /home/dot/Projects/edge-proxy-worker)
nix copy --to ssh://dot@CONDUIT_SSH_TARGET "$edge_source_store"
nix copy --to ssh://dot@HOPPER_SSH_TARGET "$edge_source_store"
```

目标账户已是受信任的 Nix 用户；复制后分别在两机用 `nix path-info` 核对同一
store 路径，再将它显式传给新模块的 `package` 选项。现有 `nixos-rebuild
--target-host` 链也会传输本地构建的闭包；Hopper 的 ARM 构建路径需继续遵循
服务器迁移文档。已在本机用隔离 file-store 复制并读回该单路径 closure，
只读 SSH 检查显示两台目标当前尚无该路径；**没有执行远程复制**。这种方式
可以完成一次受控灰度，但新工作站只克隆 dotfiles 时仍无法重建源码。长期
发布须提供可审查、可跨主机取得的同一 Git 对象或已固定的二进制缓存产物。
不得只替换旧
`pinned-source.mjs` 的提交号：旧 `deploy.mjs` 仍调用新源码已移除的
`buildProfiles`。

## canary 凭据与启用门槛

`servers/secrets/conduit.yaml` 和 `hopper.yaml` 各自保存不同的
`xray/managed_canary_uuid`、`proxy/origin_proof_key` 和
`proxy/origin_proof_token`。`servers/secrets/cloudflare.yaml` 的 `canary`
分支保存独立交付令牌、订阅令牌、两地上传 HMAC、优选池读取令牌以及探测
请求/响应 HMAC；这些值未复制到通用项目或明文配置。仅登记密文不会改变
运行服务：旧 Xray 账户目录中的 `canary.enabled` 仍为 false。

进入隔离灰度前，还需完成以下部署侧输入与实机证据：

1. 路由器在实际网络生成两地测量结果，经可信回源探测写入 `owner-campus-canary`
   的两个 v2 池；只有池格式和健康通过才允许发布。
2. 确定 probe 的独立 HTTPS 域名、证书、受限来源和运行主机，向该主机的 SOPS
   写入完整 `probe_env`；为新版 Worker 创建独立 KV、绑定和私有交付域名。
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
`edge-proxy-next` 和 `edge-preferred-control` 仍存在；新版独立优选 KV、交付 KV
及对应 Worker 尚不存在。旧 KV 和旧 Worker 需作为回退保留，不能拿来存 v2
池或账户文档。probe 的公开 HTTPS 名称、证书与访问路由没有可核验的现成部署
绑定；现有 CDN 证书只声明给各自回源虚拟主机，不能推断适用于 probe API。

probe 的公网 HTTPS 路由、证书信任、来源限制及新版 Worker 绑定需要单独审阅；
当前模块既不开放防火墙，也不覆盖旧代理路由。先在隔离环境验证错误证书、错误
nonce、错误 `originId`、错误 MAC、候选地址限制与失败保留，再分别执行两台
服务器的 `nixos-rebuild test` 并确认旧 Xray、SSH 与订阅正常。若新路径异常，
关闭相应新模块并恢复上一代系统配置；旧订阅、优选池与 Worker 不依赖这些模块。

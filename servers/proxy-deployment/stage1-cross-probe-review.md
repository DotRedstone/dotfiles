# 双节点交叉探测隔离候选审查

状态：2026-10-14。分支 `codex/cross-probe-isolated` 以 `codex/stage1-proxy-only`
为基线，提交 `d0fe51f`、`4f6509e` 只增加默认关闭的交叉探测主机入口与
DNS-01 证书选项。该候选没有改 `servers/flake.lock`、Hopper Gmail、SOPS 密文、
现用订阅、旧 Worker、旧路由、Cloudflare、DNS 或路由器；未执行远端操作。

## 探测方向与密钥

| 测量池的 `origin` | 执行探测的主机 | HTTPS 探测地址 | 被测回源身份与 TLS 名称 |
| --- | --- | --- | --- |
| `la` | Hopper | `host-1.example.test/probe` | `ORIGIN_ID_LA`；LA CDN 回源的现有 TLS 主机名 |
| `sg` | Conduit | `host-2.example.test/probe` | `ORIGIN_ID_SG`；SG CDN 回源的现有 TLS 主机名 |

方向与 `edge-proxy-worker/docs/preferred-v2.md` 的 `origins.la/sg` 契约一致：
`la` 探测器固定在 Hopper，`sg` 探测器固定在 Conduit。候选 Nix 模块只设置
`serverName` 和锁定 Worker 源码包；probe 与 ingress 默认关闭，监听地址为
`127.0.0.1:18444`。

启用前需分别在 Hopper、Conduit 的 SOPS 中增加 `proxy/probe_env`。Hopper 环境
只允许 `la`，Conduit 环境只允许 `sg`，且 `PROBE_ORIGINS_JSON` 不得包含另一地区。
每项只放对应 origin 的 `host`、443 端口、`originId`、路径 `/proof`、proof key
和 access token；`host` 必须是证书覆盖的现有 CDN TLS 名称。`PROBE_ALLOWED_CIDRS_JSON`
只列准许测试的公网候选范围。Worker 的 `PROBE_ENDPOINTS_JSON` 则分别配置两处
HTTPS URL 与请求/响应 HMAC。四把 HMAC 密钥均至少 32 字符且彼此不同；Worker 的
`la` 两把只与 Hopper 对应，`sg` 两把只与 Conduit 对应。各机 SOPS 只保存本机
探测器需要的一对，不复用历史单对密钥或 Target 凭据。

## TLS、DNS 与 Worker 前提

两个公网名称都需要覆盖自身 hostname、受系统 CA 信任的证书。现有 CDN Origin CA
证书 SAN 只覆盖旧 CDN 名称，不能用作 Worker 到探测器的公网证书。候选支持先只开
`proxyProbeIngress.acme.enable` 并保持 `enable = false`：每台使用仅能编辑
`bdot.in` DNS 记录的 `proxy/probe_acme_dns_token` SOPS 凭据签发 DNS-01 证书；
不得把 Cloudflare token 写进 Nix、普通文件或提交内容。证书签发和入口启用分开验收。
入口启用后，Nginx 复用现有 443，以专用 hostname 提供 HTTPS；仅精确 `=/probe`
转发到回环服务，其余路径 404。Nginx 到回环服务也启用 TLS/SNI、系统 CA 验证。
不新增公网端口，不改旧 CDN vhost。

Cloudflare 下一阶段的精确对象是 `bdot.in` 下两条 proxied A/AAAA 记录：
`probe-la-v2-canary` 指向 Hopper 当前源站地址，`probe-sg-v2-canary` 指向
Conduit 当前源站地址。实施前重新读取当前地址、CAA、既有 DNS/Route/Custom Domain
与配置规则；只为这两个 hostname 加 Full (strict) 规则，不改变 zone 默认 SSL
设置或旧 CDN 记录。已知的 `bdot.in/*` apex Worker Route 不覆盖这两个子域，但需用
Cloudflare Trace 和真实 canary 请求排除 wildcard/Custom Domain 冲突或同 zone fetch
递归；旧 Route 和旧 KV 均保留。

2026-10-14 直接查询 Cloudflare DNS-over-HTTPS 时，这两个新名称均为 `NXDOMAIN`；
本机系统解析器却把它们映射到 `198.51.100.10/15` 测试地址，该结果不是公网记录，
不用于配置 DNS。域名、规则、源站 IP、CAA 与 Route 在实施前仍需从权威控制面复核。

**当前 Worker 锁不能与双地区控制契约配套。** 此候选继承 `edgeProxyWorker`
`306c249`，其控制 Worker 只有单个 `PROBE_URL`、`PROBE_REQUEST_KEY`、
`PROBE_RESPONSE_KEY`。接口文档 `preferred-v2.md` 所述的
`PROBE_ENDPOINTS_JSON`（固定 `la`、`sg` 两个 endpoint 和四把互异密钥）在
`538d974` 才出现。锁定源与 `538d974` 的 `probe/server.mjs`、
`origin-proof/server.mjs` 文件相同，但这不消除控制 Worker 的接口差异。
下一步须审查并锁定双地区 Worker 修订，确认 Nix adapter/构建路径兼容；不能只凭
探测器脚本相同或本地测试通过就更新锁。新控制 Worker 使用独立资源
`CONTROL_WORKER_NAME` 和 KV `CONTROL_KV_TITLE`
（binding `PREFERRED_V2_STATE`，ID `CONTROL_KV_ID`）；不得复用旧 Worker/KV。写池前必须完成真实端到端
探测；任一来源、候选、HMAC、TLS、nonce、originId 或 proof 失败时拒绝整批写入，
KV 上次有效池保持原字节。

## 本地验证与发布门槛

- `nix flake check path:./servers --no-build --all-systems --option substituters ''` 通过：四台主机求值及 x86_64/aarch64 Worker bundle derivation。
- 合成扩展求值在 Conduit/Hopper 均确认默认 ingress、probe 和 probe systemd 服务关闭；只启用 DNS-01 时只声明 ACME 证书和 DNS token，ingress、probe 服务与 `proxy/probe_env` 仍关闭；同时启用 ingress 后，probe 绑定 `127.0.0.1:18444`，Nginx 指向该端口并设置匹配的 `proxy_ssl_name`，probe 环境与 DNS token secret、ACME 证书均进入声明配置，顶层 system derivation 可求值。示例联系人为 `example.test`，不代表部署值。
- `/home/dot/Projects/edge-proxy-worker` `npm run check` 通过：Prettier、TypeScript 与 42 项测试。该 checkout 为 `538d974`，其中测试覆盖双 endpoint、签名/回显校验、单 endpoint 不回退另一探测器，以及第二个候选失败时旧池不变；不能据此声称锁定的 `306c249` 控制 Worker 已通过新版契约测试。
- `git diff --check codex/stage1-proxy-only...HEAD` 通过；相对代理基线仅有两个 host cross-probe 模块、两个 host switchboard 导入、服务 switchboard 导入及 ingress/ACME 服务模块。`flake.lock`、Hopper Gmail 与 SOPS 文件无差异。

后续顺序：先审查 `edgeProxyWorker` 精确修订及 adapter，完成合成两地密钥映射；再分别提交两地受限 `proxy/probe_env` 与 DNS-01 token 的密文更新；先签证书但保持入口关闭，验证 SAN、链和续期；之后逐台启用 HTTPS 入口并测试正确/错误签名、nonce、候选地址、TLS 和 proof；最后才申请新增两条 proxied DNS 记录、两条 hostname-scoped Full (strict) 规则，并将新控制 Worker 绑定到专用空 KV。每一步重新核对当前路由、现网和回退闭包。

新增 DNS/规则/Worker 只服务 canary 探测，不切换客户端、旧订阅、旧池或默认路由。失败时先停新 Worker Route/调度，确认新 KV 未替换旧数据；删除新增 DNS 与 hostname-scoped 规则、关闭两地 ingress/probe，再按现场记录回退主机闭包。旧 Worker、旧 KV、旧池、旧订阅及 zone 默认 SSL 设置保持不动。证书和 SOPS 凭据在确认无消费者前保留。

## 后续 Worker 锁与本地适配候选

`codex/preferred-v2-adapter` 从本交叉探测候选另建分支，仅将 Flake 的
`edgeProxyWorker` 锁从 `306c249` 更新至 `538d974`；`gmail-archiver`
仍为 `b338d9c`，`proxyStack` 仍为 `23a64ff`。Nix 锁的 NAR hash 与实际
源码路径核对一致；两地主机继续读取该非 Flake 输入。旧版 `deploy.mjs` 与归档
`4fbe909` 的 `buildProfiles` 路径不变。

新 `prepare-v2-workers.mjs` 只为 `CONTROL_WORKER_NAME`、
`DELIVERY_WORKER_NAME` 生成独立 KV 绑定、公开变量、固定源码与 secret
来源清单，Wrangler dry run 分别打包两个入口。没有设置 Route 或上传密钥；
控制 Worker 缺少 `PROBE_ENDPOINTS_JSON`、签名密钥，交付 Worker 缺少令牌
哈希和 manifest 前不能投入使用。合成测试覆盖 LA/SG 正确探测器、签名上传、
第二候选失败时旧池保留与交付 token/修订校验；不代表公网链路已验收。

本候选不会改变服务器运行配置或现用流量。若本地评审失败，回退此分支的
Worker 锁与适配器提交即可；若以后单独部署灰度 Worker，先移除新 Route／
调度并回退至旧订阅与旧 KV，保留旧 Worker 和旧池，再按部署记录清理两个
隔离 Worker 与 KV。DNS、证书、SOPS 和主机入口仍需按上文独立验收。

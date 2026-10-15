# 双节点 v2 隔离发布前置核对

状态：2026-10-15。表格记录 2026-10-14 的只读快照；之后 Conduit 临时测试、自动回退
和正确双身份候选闭包准备见下方增量。本记录描述已核对状态及后续操作门槛，不是发布许可。
旧 Worker、旧 KV、Cloudflare、DNS 和路由器均未修改。探测方向与模块接口见
[交叉探测候选审查](./stage1-cross-probe-review.md)，部署输入见[本目录入口](./README.md)。

## 当前状态

| 对象 | 只读结果 | 发布含义 |
| --- | --- | --- |
| Cloudflare 账户边界 | `bdot.in` zone 在 `sites` 账户；现用与预留 Worker/KV 在另一个 `proxy` 账户 | DNS/证书规则和 Worker/KV 要分别核对权限，不能假定同一 token 可管理两侧 |
| 新 probe DNS | zone API 无两名的 A/AAAA；两台委派 NS 的 TCP 权威查询均为 NXDOMAIN。本机 UDP DNS 被中间层改写，非权威响应不用于发布 | `probe-la-v2-canary.bdot.in`、`probe-sg-v2-canary.bdot.in` 尚未开放 |
| 证书与规则 | Universal 边缘证书处于 active，覆盖 `*.bdot.in`；zone 无 CAA 记录。zone 默认 SSL 模式为 `flexible`，现有 Configuration Rules 与 Origin Rules 均无规则 | 边缘证书不替代两台源站的公开可信证书；必须先为两个精确 hostname 准备源站证书与 `strict` 配置规则，不能改 zone 默认模式 |
| 路由占用 | zone Worker Route 只有 `bdot.in/*` 指向既有站点 Worker；两个账户的 Worker Custom Domains 与 zone Custom Hostnames 均无新 probe 名称 | 新子域暂未被这些对象占用；发布前仍须用 Trace 和真实请求排除规则冲突及同 zone fetch 递归 |
| 旧入口 | `la-cdn`、`sg-cdn` 的现用 A 记录均为 proxied，目标与部署目录中的节点目录相符 | 新 DNS 应重新核对届时的源站地址，不复用本次快照作写入依据 |
| 旧 Worker/KV | `edge-proxy-next` 当前 100% 版本 `b976e719-fff2-42e1-b26c-3d653cd9f3f1`；`edge-preferred-control` 当前 100% 版本 `2d3d75dd-367d-4525-aa52-66b0d195aa56`。二者 `EDGE_STATE` 均指向 `edge-proxy-next-state`（`edc5684b06104774931e664f9d761349`），该 KV 可列出 7 个键 | 不覆盖旧 Worker、旧 KV、旧绑定或订阅；上述版本号只标识 Cloudflare 当前部署，不能推断其源码 Git 修订 |
| 隔离资源 | `edge-proxy-v2-canary-preferred` 和 `edge-proxy-v2-canary-delivery` 两个独立 KV 已存在、各 0 键；`edge-preferred-v2-canary` 与 `edge-delivery-v2-canary` Worker 均不存在 | 新控制与交付只能绑定各自隔离 KV；发布配置尚无 Route 与 secret |
| 两台主机 | Conduit/Hopper 均运行 NixOS `26.11.20260831.34ab990`，Nginx、Xray、`proxy-origin-proof` active，443 均有监听；新 `proxy-preferred-probe` 与交付 timer inactive，新 probe vhost 不在当前 Nginx 配置中 | 当前服务不等于本分支的声明式候选；应逐台核对 SSH、旧身份与旧订阅后才做未来 `test` |
| 闭包 | 两台的 `/run/current-system`、`/run/booted-system`、system profile 三者两两不同 | 先查明当前临时激活配置与下次启动代际；不能从现有 profile 推断运行状态，也不能直接对 Hopper 做整机切换 |
| SOPS | 两地主机密文及运行时均有 `proxy/origin_proof_key`、`proxy/origin_proof_token`。两地均缺 `proxy/probe_env`、`proxy/probe_tls_cert`、`proxy/probe_tls_key`、`proxy/probe_acme_dns_token`、`proxy/delivery_runtime`。Cloudflare canary 有上传密钥和优选读取令牌，只有历史单对 probe HMAC；无两地区 `probe_endpoints_json` 或交付令牌哈希 | 四把互异 probe HMAC、两机各自仅含获准回源的环境、DNS-01 凭据和交付运行时尚须在受限环境准备。选 ACME 时证书／私钥来自 ACME，后两项 SOPS TLS 键不必同时配置；本记录不含密钥内容 |
| 私有源码 | 本机锁定 Worker `538d974` 的 NAR hash 与源码可读；两台构建端均无该源码 store path。远端 Worker Git SSH 因 host key 未建立而拒绝，私有 `proxy-stack` HTTPS 无非交互凭据 | 远端直接拉取私有输入尚未证明可行；先审查可信 host key/凭据或从本机传输固定闭包，再核对 NAR hash，勿因本机求值通过就执行远端构建 |
| 路由器安装包 | 协同只读核对确认目标为 Netcore N60 Pro 的 Kwrt 25.12-SNAPSHOT，软件包管理为 opkg/IPK；`cf-optimizer` 已有双 probe 合成夹具，但缺对应 SDK，尚无可安装 IPK | 路由器真实测量与上传未就绪，不能把合成测试当作可发布的两地 v2 池 |

以上 Worker 绑定只列名称与类型：旧主 Worker 另有 `CONFIG_TOKENS`、
`IP_UPDATE_KEY`、`PREFERRED_ENDPOINTS_TOKEN`、`ROUTE_SECRET`、
`SUBSCRIPTION_TOKEN`、`TROJAN_PASSWORD`、`VLESS_UUID` Secret；旧控制 Worker
另有 `IP_UPDATE_KEY`、`PREFERRED_ENDPOINTS_TOKEN` Secret。旧主 Worker 的
`DOH_URL`、`PUBLIC_HOST`、`SITE_NAME` 为普通变量；两者的 compatibility date
均为 `2026-09-01`。未读取变量或 Secret 的值。

### 2026-10-15 Conduit 轮换候选修正与目标 store 准备

此前 Conduit 临时 `test` 误用了不含轮换账户的闭包
`/nix/store/vva6zja3bhd6mdc62vmq6kjx1dwvr7yd-nixos-system-conduit-26.11.20260831.34ab990`
（deriver `1921siaa5050zkfjh34y2pjk55cg89x9`）。20 分钟 timer 后通过旧闭包
`switch-to-configuration test` 自动回退成功；journal 记录 service 成功结束，current
恢复为测试前的 `/nix/store/ajayszz54z693qsrmvr6jc77n94gmcrp-nixos-system-conduit-26.11.20260831.34ab990`，
marker 已清除，timer/service 已清理。回退后 sshd、Nginx、Xray、订阅检查及
`proxy-origin-proof` active；旧 Reality、`guest`、`canary` 身份存在，三条订阅与模板
逐字节一致，proof 正确/错误令牌分别返回 200/404；Hopper current 与服务状态未变。

提交 `78a1742` 的闭包 `k97d7qm…` 虽含 rotation，但 Reality 订阅把旧 primary UUID
换成 rotation。该闭包已复制到 Conduit store，**只作为历史候选留存，禁止激活**。
窄化后的提交 `e08492a` 仅恢复 Conduit、Hopper 两份 SOPS 中的 Reality 订阅正文；
服务端 rotation 密钥与启用项、原 primary/vision 密钥继续保留。该阶段不把新 UUID
发布到任何既有订阅。

以功能提交 `e08492a` 求值时，锁定 `proxyStack` revision
`5393d0e1bffd3406b62b09269b54fd7434778f3e`（NAR
`sha256-0XNue1CC3fs0kTAsQB/zSs64Su+8y/UQ2poi+0F1E+g=`），Worker revision
`538d974998f217a7a10cd8a178b62e82d44fcb89`（NAR
`sha256-8IzmqzVJrw/oMnT0+/E2tc1lj96QLDImdKmkFuy5f3I=`）。Conduit top-level deriver 为
`/nix/store/5fa287a1bi8minfp3jz046sl88w38k3f-nixos-system-conduit-26.11.20260831.34ab990.drv`，
输出为 `/nix/store/fkq5h093an3qjynycv13awr76fdlra20-nixos-system-conduit-26.11.20260831.34ab990`；
完整闭包构建成功，4 个 derivation 完成，闭包约 1.93 GB。SOPS manifest 含
`xray/managed_rotation_uuid`；Conduit 与 Hopper Xray 模板均含旧 primary、vision、
`managed:guest`、`managed:canary` 和 `managed:rotation`。两地 SOPS 解密检查确认新
rotation 密钥与旧 identity 保留。

订阅逐字节对照共 8 条：Conduit 3/3、Hopper 5/5 的正文和路径均与各自主机当前
运行模板相同；检查覆盖 WebSocket、Reality、CDN，以及 Hopper 的 Hysteria2 和 guest。
Xray 26.3.27 使用两地候选模板和各自主机 SOPS 值分别运行 `xray run -test`，均通过。
解密值仅经内存管道进入 `/run/user` 下的 0600 临时配置与日志，检查后删除；未写入
Nix store、文档或命令输出。

Conduit 完整闭包已复制到目标 store。目标端 deriver 与本机相同，NAR hash 为
`sha256-tBwD+MPIpQUnmXgcr13/wOPYLiA1gYHcHW1kXl79Y8Q=`，NAR size `253760`；远端
`nix store verify --no-trust` 通过。复制后 current 仍为旧闭包；timer 不存在且
marker 不存在。Hopper 顶层已完成求值，未构建完整 ARM 闭包。本轮没有安装 timer、
创建 marker、执行 `test`/`switch`、修改 DNS/Worker/路由器或撤销旧身份；待主会话复核
Reality 旧订阅兼容边界后再决定下一步。

### 2026-10-15 Conduit 双身份临时验收

在主会话复核正确候选与旧订阅边界后，使用同一已核对的 Git HEAD
`3b4d6013888ceb1e3176973c8569c7c6e03e7eed` 对 Conduit 执行临时
`nixos-rebuild --no-reexec test --store-path`。候选运行闭包为
`/nix/store/fkq5h093an3qjynycv13awr76fdlra20-nixos-system-conduit-26.11.20260831.34ab990`；
系统 profile 和 `/run/booted-system` 仍指向此前闭包，因此这不是持久 `switch`，重启后
将回到旧 profile。

临时验收确认 Xray 的 `LoadCredential` 运行配置与 SOPS 渲染配置逐字节一致，并同时含旧
Reality primary、旧 Vision、`managed:guest`、`managed:canary` 与新
`managed:rotation`。WebSocket、Reality、CDN 三条旧订阅均返回 HTTP 200，响应正文与本机
SOPS 密文解码所得订阅正文一致；`/proof` 的有效与无效访问令牌分别返回 200 和 404。
用临时 Xray 客户端分别经旧 Reality primary 与新 rotation 实际访问外网回显服务，两者
均成功，出口 IP 均与 Conduit 直连出口一致。临时客户端进程和文件已清理。

验收成功后取消并清理回退 timer 与 marker；复核 timer `LoadState=not-found`、回退
service `Result=success` 且退出码为 0、marker 不存在。Conduit 的 `sshd`、Nginx、Xray
和 `proxy-origin-proof` 均 active。当前仍运行临时测试闭包；本记录不构成持久切换或
Hopper 激活许可。Hopper 未执行 `test`/`switch`，也未安装回退 timer；本阶段没有改动
DNS、Worker、路由器或撤销旧身份。

### Hopper ARM 候选首次构建结果

同一 HEAD 的 Hopper 候选求值结果为
`/nix/store/zih3d013lk3rd391j0wqk9s9gxk4arwh-nixos-system-hopper-26.11.20260831.34ab990.drv`
→ `/nix/store/fznhzd6b9fxyc42zphwlq7sznp5045b6-nixos-system-hopper-26.11.20260831.34ab990`。
与上一双身份候选相比，完整引用闭包只有 6 个旧路径与 6 个新路径不同；但本机 x86
构建因 ARM 平台不匹配而失败，转用 Hopper 单并发远程构建后，15 分钟仍未完成并超时。
目标端未找到新候选输出，旧候选输出仍在 store 中。超时后确认 Hopper 的
`/run/current-system`、`/run/booted-system` 与系统 profile 仍分别指向原有闭包，
`sshd`、Nginx、Xray、`proxy-origin-proof`、`gmail-archiver` 均 active，回退 timer
不存在且 marker 缺失；旧订阅在构建前均已核对为 5/5 HTTP 200 且与当前 SOPS 内容一致。
该次构建没有完成目标 store 完整性验证，因此不能作为 Hopper 激活候选。未执行 Hopper
`test`/`switch`，也未改动 DNS、Worker、路由器或旧身份；远程构建可能留下未引用的部分
store 路径，未做清理。

### Hopper ARM 候选原生构建复核

首次超时后确认 Hopper 没有残留构建进程；后续原生构建也未受锁阻塞。上一候选的推导
引用闭包仍完整保留 19,907 条路径。将同一 HEAD 的顶层 `.drv` 复制到 Hopper 时，
Nix 实际只传输 6 条新路径；目标端 `nix-store --realise --dry-run` 只列出 5 个待构建推导。随后在 Hopper
本机执行 `nix-store --realise`，约 5 秒完成，输出为
`/nix/store/fznhzd6b9fxyc42zphwlq7sznp5045b6-nixos-system-hopper-26.11.20260831.34ab990`。
该路径的 deriver 是上述 `zih3d013…` 顶层 `.drv`，NAR hash 为
`sha256-UaZ+LG6l9SLA32o0PeK2lXSLa/L8RiIrHELzW7nkV2I=`，NAR size 为 `365744`。
目标端对 6,381 条运行闭包路径执行 `nix store verify --recursive --no-trust` 内容扫描，
未报错误；顶层内容校验和递归闭包有效性校验的退出码均为 0。`flake.lock` 的
`proxyStack` 与 Worker revision/NAR 仍为上文记录的固定值；从候选 HEAD 到本记录提交
仅有本文档变化，再次求值所得 `.drv` 路径不变。

构建后再次请求 Hopper 的 Hysteria2、WebSocket、Reality、CDN 与 guest 五条旧订阅：
均为 HTTP 200，正文分别与当前 SOPS 内容逐字节一致。`/run/current-system`、
`/run/booted-system` 和系统 profile 仍分别为原有闭包；`sshd`、Nginx、Xray、
`proxy-origin-proof`、`gmail-archiver` 均 active，回退 timer 不存在且 marker 缺失。
本次仅增加 Nix store 内容，未激活候选或改动公网入口。候选输出未添加 GC root；后续
使用前须重新确认路径仍在目标 store，并复核当前运行基线与密钥。
Hopper 下一次临时 `test` 的固定时刻回退、验收与无带外恢复风险见
[Hopper rotation 临时测试交接](./hopper-rotation-test-handoff.md)。

后续每次激活前必须逐项核对并记录 **精确 Git HEAD → `flake.lock` 输入 revision/NAR →
求值 `drvPath` → `toplevel outPath` → 目标 store deriver/NAR hash → 目标端完整 store
verify**。所有值必须对应同一候选，目标 current/profile 必须仍与现场基线吻合；
不得用分支名、缩写路径或历史候选标识代替该链。任何一项不匹配时停止激活。

## 依赖顺序、影响与回退

| 顺序 | 完成条件与可执行检查 | 影响与回退 |
| --- | --- | --- |
| 0. 固定基线 | 保存两台当前、开机、profile 闭包的受限现场记录，解释三者差异；复核 Hopper Gmail 现网基线、SSH 保活、旧 Xray 身份和订阅。对本分支形成包含现网基线的整机候选 | 仅核对时无流量影响；闭包来源不清时停止发布 |
| 1. 私有输入与密钥 | 在两构建端证明固定 Worker/编译器修订可读或由本机传输固定闭包；核对 NAR hash。分别准备两地 `probe_env`、DNS-01 最小权限 token、四把互异 HMAC，确保 Hopper 仅允许 `la`、Conduit 仅允许 `sg`，并准备交付运行时及令牌哈希 | 仅增加受限输入；不复用旧单对探测密钥。失败时保留旧 SOPS 路径，停止后续阶段 |
| 2. 先签证书 | 仅开启两地 DNS-01 证书选项，probe/ingress 保持关闭；验证证书 SAN、公开信任链、续期、Nginx 可读权限与两地 SOPS 分离 | 仅 ACME DNS TXT 临时记录和证书状态受影响；签发失败时关闭新 ACME 选项，不动旧 CDN 证书与 vhost |
| 3. 逐台试入口 | 先在一台执行受控 `nixos-rebuild test`，确认 loopback probe、443 专用 vhost、SNI/证书、错误签名、nonce、候选范围、proof 后再测另一台；旧 Nginx/Xray/SSH 同时检查 | 新 hostname 的 443 路由出现，旧路径应保持；失败时停新 probe/ingress、恢复上一代临时配置，核对旧订阅和 SSH |
| 4. 开 DNS 与严格回源 | 在 `sites` zone 先建仅匹配两个新 hostname 的 `strict` Configuration Rules，再核对源站证书与现时 IP，新增两条 proxied A/AAAA；从权威 NS TCP、Cloudflare Trace 和外部 HTTPS 验证两地路由 | 仅新 probe 子域受影响；失败时移除新 DNS/精确规则并关闭新 ingress。不得改变 `flexible` zone 默认设置或旧记录 |
| 5. 新控制 Worker | 审阅 `prepare-v2-workers.mjs` 产物、独立 `PREFERRED_V2_STATE` KV、两地区 `PROBE_ENDPOINTS_JSON`、签名密钥及受限 Route；先做无写探测与错误注入，再以隔离来源上传真实测量 | 仅隔离 Worker/KV 写入；任一探测失败应保留该 KV 旧池。失败时停新 Route/调度，保留旧 Worker/KV 和订阅 |
| 6. 测量与交付 | 取得匹配 Kwrt 的 SDK 并生成/验收 IPK，确认路由器真实网络两地测量；只有两地有效池后才启用单主机 publisher，写完并读回五份私有文档后切换 manifest；再部署 `DELIVERY_STATE` Worker 与受限入口，测试三平台下载、provider、单账户停用 | 仅 canary 客户端接入；失败时停 publisher/新 Route，恢复上一个 manifest，隔离 KV 可留待审计；旧订阅、旧池和路由器默认组继续可用 |

所有阶段执行前重新读取 Cloudflare 与主机状态。尤其第 4 阶段的 zone 默认
`flexible` 不能作为受信任回源证据；Cloudflare 的 [加密模式说明](https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/)
与 [Configuration Rules 设置](https://developers.cloudflare.com/rules/configuration-rules/settings/)
说明可将 `strict` 限定到匹配的 hostname。Universal 边缘证书覆盖一级子域，
但仅在记录 proxied 后提供给访问者，见 [Universal SSL 文档](https://developers.cloudflare.com/ssl/edge-certificates/universal-ssl/enable-universal-ssl/)。
同 zone Worker Route 不能作为 `fetch()` 的目标；发布前需核对
[Worker 路由规则](https://developers.cloudflare.com/workers/configuration/routing/)并通过实际请求验证。

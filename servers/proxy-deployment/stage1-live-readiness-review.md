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
Hopper 后续临时 `test` 的固定时刻回退、验收与无带外恢复风险见
[Hopper rotation 临时测试交接](./hopper-rotation-test-handoff.md)。

### Hopper rotation 临时测试完成

2026-10-15 后续执行了 Hopper 候选的临时 `test`。当前运行闭包为 `fznhzd6b…`，
启动闭包和系统 profile 保持旧值；回退 timer 已停止、marker 已清除。旧订阅、旧身份、
新 rotation、proof、Gmail 与从 Conduit 发出的实际代理请求均通过本轮验收。
执行顺序、具体证据和重启风险见
[Hopper rotation 临时测试交接](./hopper-rotation-test-handoff.md)。尚未执行持久
`switch` 或修改 DNS、Worker、路由器和旧身份。

### Conduit 持久化前只读核对

2026-10-15 复核：Conduit current 仍为已验收的 `fkq5h093…` 临时闭包，booted 为
`8alf4971…`，系统 profile 第 20 代为
`/nix/store/92j5wm1b6jzjkv8rrx7xj9nahggqkglm-nixos-system-conduit-26.11.20260831.34ab990`。
当前候选 deriver `5fa287a1…` 与本地求值一致，目标 NAR hash 仍为上文记录值，
`nix store verify --no-trust` 退出码为 0。`sshd`、Nginx、Xray、`proxy-origin-proof`
均 active；运行凭据与 SOPS 渲染逐字节一致，三条旧订阅均为 HTTP 200 且正文不变。
当时 Hopper 的新候选尚未激活，因此这里没有执行 Conduit 持久 `switch`。

若后续获准持久化，应先保存并再次确认上述 profile 第 20 代路径，为恢复旧启动配置
准备独立的固定时刻回退保护；然后才可对当前已验收候选执行
`nixos-rebuild --no-reexec switch --store-path`。SSH 仍可用时的最小手动恢复命令拟为：

```bash
sudo nixos-rebuild --no-reexec switch --store-path \
  /nix/store/92j5wm1b6jzjkv8rrx7xj9nahggqkglm-nixos-system-conduit-26.11.20260831.34ab990
```

该命令尚未执行，也未验证失联时可完成恢复；执行后还须核对 current/profile、Xray
运行凭据、旧身份与旧订阅。服务商救援入口在迁移文档中有说明，但本阶段未验证可用。
在固定时刻回退方案实测且获得单独授权前，不以当前 `test` 的成功代替持久切换验收。

路由器 Mihomo 控制端口可达，但只读 `/proxies` 请求返回 401；仓库内现用
`clash/router-policy.json`、移动热点策略及待发布 router profile 均未保存控制器
secret，本机也无运行中的 Mihomo 控制器。现阶段无法核实路由器各组的实际 `now`；
源码里的 `DIRECT` 规则不能替代该运行态证据。

后续每次激活前必须逐项核对并记录 **精确 Git HEAD → `flake.lock` 输入 revision/NAR →
求值 `drvPath` → `toplevel outPath` → 目标 store deriver/NAR hash → 目标端完整 store
verify**。所有值必须对应同一候选，目标 current/profile 必须仍与现场基线吻合；
不得用分支名、缩写路径或历史候选标识代替该链。任何一项不匹配时停止激活。

### 2026-10-16 隔离控制面只读更新

此前表格是 2026-10-14 快照。2026-10-16 从两套 Cloudflare 账户分别只读核对：
`sites` 令牌可读取 `bdot.in` zone、DNS、规则与路由；`proxy` 令牌可读取 Worker
和 KV。两者读取各自账户资源均返回 200，未验证写权限；`/user/tokens/verify`
对两枚令牌均返回 401，因此不能以该端点推断资源读取权限。两个新 probe 名称
仍无 DNS 记录，zone 只有原有一条 Worker Route，未发现 probe Custom Domain。

`edge-preferred-v2-canary` 与 `edge-delivery-v2-canary` 现均有部署，分别绑定目录中
指定的独立 KV 及所需 secret；两个隔离 KV 均为 0 键。两 Worker 的 `workers.dev`
和 preview 均关闭，没有可供本阶段验收的公网入口。Cloudflare canary SOPS
密文已包含 `probe_endpoints_json`：两地区 URL 为预定 probe 名称，四把 HMAC
密钥互异且长度均为 64。密文存在及 Worker secret 绑定不能证明值一致或探测
可用。重新按 `proxy` 嵌套字段解密核对后，两台 SOPS 均已有 `probe_env` 和
专用 TLS 全链／私钥；Conduit 有 `delivery_runtime`，Hopper 无此项。此前按
带斜杠的顶层键检查得出的“缺少 probe 输入”结论无效。

运行 `node servers/proxy-deployment/scripts/check-probe-inputs.mjs`，两台输入均通过
锁定 probe 实现的配置校验：Hopper 只允许 `la`，Conduit 只允许 `sg`；各自的
请求/响应密钥与 Cloudflare 对应地区一致，proof 凭据来自对侧主机；专用证书
覆盖相应 probe 名称、私钥匹配、链可由本机系统 CA 验证，有效期至 2027-01-12。
没有 `proxy/probe_acme_dns_token`，当前静态证书路径不启用 ACME；续期方式仍需
在证书到期前确定。两台合成求值仅打开 probe ingress 时，均能生成顶层
derivation 并引用已有三项 SOPS 输入，ACME 仍关闭；这不证明目标机渲染、
Nginx TLS、probe 服务或公网流量已通过。

`cf-optimizer` 已可在本机生成 SDK-free 的 arm64 后端和 `all` 架构 LuCI IPK
候选；本轮归档结构、ELF 架构、依赖声明及权限检查通过。未获得目标 Kwrt 的
包安装、依赖解析或 LuCI/rpcd 运行证据，不能将该候选称为路由器可安装版本。
路由器 Mihomo `/proxies` 本轮只读请求仍返回 401，组 `now` 未知。

## 依赖顺序、影响与回退

| 顺序 | 完成条件与可执行检查 | 影响与回退 |
| --- | --- | --- |
| 0. 固定基线 | 保存两台当前、开机、profile 闭包的受限现场记录，解释三者差异；复核 Hopper Gmail 现网基线、SSH 保活、旧 Xray 身份和订阅。对本分支形成包含现网基线的整机候选 | 仅核对时无流量影响；闭包来源不清时停止发布 |
| 1. 私有输入与密钥 | 在两构建端证明固定 Worker/编译器修订可读或由本机传输固定闭包；核对 NAR hash。复核已有两地 `probe_env`、静态证书、四把互异 HMAC 和对侧 proof 映射；确定单主机 publisher 并验收其交付运行时与令牌哈希 | 只读检查无流量影响；映射不符时停止后续阶段，不覆盖旧 SOPS 路径 |
| 2. 证书就绪 | 使用已有静态证书时，先在目标机只读核对 SOPS 渲染、证书名称、公开信任链、有效期及 Nginx 可读权限；probe/ingress 保持关闭。到期前另定续期方式；若改用 DNS-01，需另备限权 token 并分阶段验收 | 本轮只读检查无流量影响；证书不符时停在入口激活前，不动旧 CDN 证书与 vhost |
| 3. 逐台试入口 | 先在一台执行受控 `nixos-rebuild test`，确认 loopback probe、443 专用 vhost、SNI/证书、错误签名、nonce、候选范围、proof 后再测另一台；旧 Nginx/Xray/SSH 同时检查 | 新 hostname 的 443 路由出现，旧路径应保持；失败时停新 probe/ingress、恢复上一代临时配置，核对旧订阅和 SSH |
| 4. 开 DNS 与严格回源 | 在 `sites` zone 先建仅匹配两个新 hostname 的 `strict` Configuration Rules，再核对源站证书与现时 IP，新增两条 proxied A/AAAA；从权威 NS TCP、Cloudflare Trace 和外部 HTTPS 验证两地路由 | 仅新 probe 子域受影响；失败时移除新 DNS/精确规则并关闭新 ingress。不得改变 `flexible` zone 默认设置或旧记录 |
| 5. 隔离 Worker 入口 | 审阅已部署 Worker 的版本、独立 KV、secret 绑定及受限 Route；确认运行 secret 与加密输入一致。先做无写探测与错误注入，再以隔离来源上传真实测量 | 仅隔离 Worker/KV 写入；任一探测失败应保留该 KV 旧池。失败时停新 Route/调度，保留旧 Worker/KV 和订阅 |
| 6. 测量与交付 | SDK-free IPK 仅通过本机归档检查，仍须在目标 Kwrt 验证 opkg、依赖、LuCI/rpcd、真实网络两地测量与并行旧任务；只有两地有效池后才启用单主机 publisher，写完并读回五份私有文档后切换 manifest；为已部署交付 Worker 配置受限入口，测试三平台下载、provider、单账户停用 | 仅 canary 客户端接入；失败时停 publisher/新 Route，恢复上一个 manifest，隔离 KV 可留待审计；旧订阅、旧池和路由器默认组继续可用 |

所有阶段执行前重新读取 Cloudflare 与主机状态。尤其第 4 阶段的 zone 默认
`flexible` 不能作为受信任回源证据；Cloudflare 的 [加密模式说明](https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/)
与 [Configuration Rules 设置](https://developers.cloudflare.com/rules/configuration-rules/settings/)
说明可将 `strict` 限定到匹配的 hostname。Universal 边缘证书覆盖一级子域，
但仅在记录 proxied 后提供给访问者，见 [Universal SSL 文档](https://developers.cloudflare.com/ssl/edge-certificates/universal-ssl/enable-universal-ssl/)。
同 zone Worker Route 不能作为 `fetch()` 的目标；发布前需核对
[Worker 路由规则](https://developers.cloudflare.com/workers/configuration/routing/)并通过实际请求验证。

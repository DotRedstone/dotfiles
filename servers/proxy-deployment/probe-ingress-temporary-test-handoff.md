# 双节点 probe ingress 临时测试交接

状态：2026-10-16。两台 rotation 候选已持久切换，观察结果见
[双节点持久切换交接](./dual-node-persistence-handoff.md)。Conduit 首次 probe ingress
`test` 因 Nginx 校验上游证书链失败而回退；下表的修正候选随后完成临时 `test`。
Hopper 原候选因证书访问权限不足禁止激活；修正候选已在 ARM 目标机构建，
尚未执行临时 `test`。两台均未对 probe
候选执行 `switch`。本轮没有修改 DNS、Cloudflare、路由器或旧订阅。

原始源码锚点为 `99bfdc1f7e754f16e706cf2046f3d27702fb3975`。Conduit 当前修正
锚点为 `765ab49f5a32c647f6a2112db66dfc3aca0eae1d`；Hopper 修正候选也基于
该源码，两台均仅通过
`extendModules` 将 `dot.services.proxyProbeIngress.enable` 设为 true，ACME 仍关闭。
回退脚本及本文的后续提交不改变候选 Nix 输入。入口与密钥边界见
[代理部署数据](./README.md#回源证明与可信探测)。

## 离线候选和运行基线

| 主机 | 顶层 deriver | 顶层 outPath | 持久 rotation 运行闭包与系统 profile | 当前 booted |
| --- | --- | --- | --- | --- |
| Conduit | `/nix/store/44yhk9j85q4kavjpp09wwfb7iskzpbxf-nixos-system-conduit-26.11.20260831.34ab990.drv` | `/nix/store/73qxjfv9l6fjp73fvqpi31a02gnnvwd4-nixos-system-conduit-26.11.20260831.34ab990` | `/nix/store/fkq5h093an3qjynycv13awr76fdlra20-nixos-system-conduit-26.11.20260831.34ab990` | `/nix/store/8alf4971c77zpy5rb6rbdzbik12617pa-nixos-system-conduit-26.11.20260831.34ab990` |
| Hopper | `/nix/store/2am5m5hiz4b3h1p4pyknmhif5h7ipxbg-nixos-system-hopper-26.11.20260831.34ab990.drv` | `/nix/store/irwzjkl39v1ra9la699smvymkxpbgzz8-nixos-system-hopper-26.11.20260831.34ab990` | `/nix/store/fznhzd6b9fxyc42zphwlq7sznp5045b6-nixos-system-hopper-26.11.20260831.34ab990` | `/nix/store/k69xg4y5d9qvp7w37p98q6vbfl0i1kgn-nixos-system-hopper-26.11.20260831.34ab990` |

Conduit 修正候选的 deriver、outPath 在本地重新求值与目标机一致；目标 NAR hash
为 `sha256-GgIDnTofFa1gvwG5pBdvB4oKBiBo7MuPyXh8jhSoczI=`、NAR size 为
`253760`，目标 `nix store verify --no-trust` 退出 0。目标
`sudo <outPath>/bin/switch-to-configuration dry-activate` 退出 0，预计新增
`proxy/probe_env`、`proxy/probe_tls_cert`、`proxy/probe_tls_key` 三项运行 secret，
重启 `nginx.service` 并启动 `proxy-preferred-probe.service`；current/profile 仍为
持久 rotation 闭包，probe 仍 inactive。Hopper 修正候选在目标 ARM 机原生构建，
deriver 与表中一致，NAR hash 为
`sha256-o2UjFfXd//U42mUDRFv78rOTkuHPr8ZTRf+55Zo+yQI=`、NAR size 为
`365744`，目标 `nix store verify --no-trust` 退出 0。目标 `dry-activate`
退出 0，预计新增同样三项 probe secret、重启 Nginx 并启动 probe；证书和私钥
声明为 root:nginx 0440，`proxy_ssl_verify_depth 2` 只作用于 `/probe` 上游。
旧 Hopper `1fkrcil…` → `zylxw91…` 缺证书权限修正，已作废，禁止激活。
下述现场记录说明 Conduit 新候选的实际运行验收范围。

### Conduit 证书权限修正

原 Conduit 候选 `4m8y9bl…` → `n2hdcal…` 在前置检查中发现：Nginx 以 `nginx`
用户运行，但 probe 证书和私钥声明为 root:root 0400，因此旧候选禁止激活。
修正后两机求值均确认：启用 ingress 时证书与私钥为 root:nginx 0440，密钥轮换
同时重启 Nginx 与 probe；仅启用回环 probe 时保持 root:root 0400，
`proxy/probe_env` 在两种情形下均保持 root:root 0400。现有 CDN 凭据使用同一
root:nginx 0440 访问边界。Conduit 目标机使用自身 SSH 身份在受限 `/run` 临时目录
解密候选 store 中的密文，验证 probe 环境只指向对侧 `sg-origin`、专用证书覆盖
`probe-sg-v2-canary.bdot.in`、证书链受系统 CA 信任、有效期及私钥配对均正确；
临时材料已清理。首次 `test` 已证明 Nginx 能读取证书、probe 能在回环提供
可信 TLS，但未通过 Nginx 上游验证；修正后的运行结果见下文。

### Conduit 首次测试与证书链深度修正

2026-10-16 01:50 CST 为首次候选 `vn243n42…` → `k0hcr1aw…` 建立截止
02:10 CST 的固定回退 timer，读回剩余 20 分钟后设置 root-only marker，执行一次
`nixos-rebuild --no-reexec test --store-path`。current 转为该候选，profile、GRUB
默认项、booted 和旧服务保持原状态；证书与私钥实际为 root:nginx 0440，probe
只监听 `127.0.0.1:18444`。直连 probe 后端的公开 CA 校验通过；Nginx `/probe`
却返回 502，journal 报 `upstream SSL certificate verify error: (20:unable to get local issuer certificate)`。
原配置 `proxy_ssl_verify on` 未设置 `proxy_ssl_verify_depth`，默认深度 1。
静态 fullchain 含 4 张 PEM；使用候选同一 CA bundle 对 leaf 与 chain 验证，深度
1 失败、深度 2 成功。因此仅为该 `/probe` 上游增加
`proxy_ssl_verify_depth 2`，继续开启名称与 CA 验证。生成的 Nginx 配置相较首次
候选仅增加该行。

01:52 CST 在 timer 与 marker 保护下手动执行回退脚本，恢复 current/profile/GRUB
为持久 rotation，booted 保持原闭包；probe 停止且三项 probe secret 移除。
SSH、Nginx、Xray、订阅检查与 proof 服务 active，Xray 运行凭据与渲染文件逐字节
一致，三条旧订阅 HTTP 200 且正文与渲染文件一致。旧 Reality、rotation Reality、
Vision、CDN、WebSocket 的真实 HTTPS 出口和旧 proof 的合法/非法 HMAC 结果均通过。
01:54:03 CST 停止 timer、确认 inactive 后删除 marker。首次候选 `k0hcr1aw…`
禁止再次激活。

### Conduit 修正候选临时测试

2026-10-16 01:59:28 CST 为 `44yhk9j…` → `73qxjfv…` 建立截止 02:19:28 CST
的固定回退 timer，读回 active、`AccuracyUSec=1s`、`Persistent=no`、精确脚本
`ExecStart` 和剩余 20 分钟后，设置 root:root 0600 marker 并执行一次精确候选的
`nixos-rebuild --no-reexec test --store-path`，退出 0。current 变为 probe 候选；
profile、GRUB 默认项仍为持久 rotation，booted 为旧闭包。SSH、Nginx、Xray、
订阅检查、origin-proof、probe 均 active；probe 仅监听 `127.0.0.1:18444`。
证书与私钥为 root:nginx 0440，可由 Nginx 读取；probe 环境为 root:root 0400，
Nginx 不可读取。Xray 运行凭据与渲染配置逐字节一致，旧身份保持不变。

Conduit 回环及自身公网 IP、新名称 SNI 的无签名 `/probe` 均通过公开 CA 验证并
返回 404；Hopper 到 Conduit 公网 IP 的同项检查也通过。经 Hopper 外部 TCP
路径发送合法签名，得到 200，响应字段和 HMAC 校验通过；错误签名、过期时间戳、
越界地址分别返回 404、404、422。对侧 SG origin 的 proof HMAC 返回 200。
三条旧订阅从 Conduit 本机及 Hopper 外部公网路径均为 HTTP 200，正文与 SOPS
原文逐字节一致；旧 Reality、rotation Reality、Vision、CDN、WebSocket 五路
真实 HTTPS 出口和旧 proof 200/404 均通过。Nginx/probe 近期无错误日志。
Warden 直连 Conduit 公网 IP 与新 SNI 在 TLS 握手处收到 reset；这一单独
客户端路径未通过，Hopper 外部源站路径通过，不能据此声称所有网络均可达。

02:03:19 CST 停止 timer 前剩余 969 秒，确认 inactive 后删除 marker；本次仅
临时 `test`，未执行持久 `switch` 或重启。以该时刻为观察起点，至 02:13:44 CST
满 10 分 25 秒后最终复核：current 仍为 probe 候选，profile/GRUB 默认项仍为
rotation，booted 未变；上述六项服务 active、Xray 运行凭据仍匹配、timer inactive、
marker 不存在，Nginx/probe 无错误日志。Hopper 外部公网路径的新 SNI、合法签名
200/响应验签与三类拒绝再次通过；三条旧订阅在观察结束后仍为 200 且正文不变，
旧五路 HTTPS 出口与 proof 于观察末复测通过。临时运行态已验收，持久启动行为
没有改变。

## 逐机测试前置条件

Conduit 修正候选已完成验收并观察超过 10 分钟。Hopper 有效候选及回退脚本
已准备，仍须完成独立前置核对后才能进入测试窗口。每台均要保留两条
SSH 会话，核对另一条重连路径；Hopper 没有已验证带外控制台，失联后的 timer
不能保证可执行，重启也不会延续临时 timer。任一时刻只能有一台处于本测试窗口。

1. 从修正源码重新求值，确认本机 deriver、outPath、目标 store 校验及三条
   系统闭包与表一致。确认默认启动项精确指向
   rotation、无其他回退 timer/marker。
   `booted` 旧闭包不是本次临时测试的回退目标；回退目标是持久 rotation 闭包。
   检查旧 SSH、Nginx、Xray、origin-proof、Hopper Gmail，以及
   Conduit 3 条、Hopper 5 条旧订阅均为 HTTP 200 且正文与此前基线逐字节相同。
2. 在**目标机**用受限临时目录从目标 store 中的加密 SOPS 源渲染三项 probe 输入，
   不打印或传出私钥与 HMAC。核对静态全链与私钥匹配、SAN 覆盖本机 probe 名称、
   系统 CA 可验证链、有效期、Nginx 可读取证书与私钥，并核对环境只指向对侧
   origin。当前静态证书有效期至 2027-01-12；续期尚未确定。任何渲染或权限
   不符合预期时停止，不以 `dry-activate` 的“would add secrets”代替此检查。
3. 核对 [回退脚本](./scripts/probe-ingress-test-rollback.sh) 的 SHA-256 为
   `f2c2ff0bad50d862eaf6e9f337d9f104d23df97d30a2f038ba1af1e423725349`，
   安装在目标 `/run/stage1-probe-ingress-rollback.sh`，归属 root、权限 0700。
   marker 缺失且 current/profile/default boot 为 rotation、booted 为表中旧闭包时，
   脚本无变更返回 0；Hopper 已安装新版脚本，目标 SHA 与源码一致、root:root
   0700，并直接演练此分支。Conduit 当前运行 probe 候选、marker 缺失，
   因 current 不等于 rotation，新脚本的无 marker 演练按预期拒绝；不应为演练
   停止已验 probe。Conduit 原脚本已在其 rotation 基线完成过 no-op 演练。
   marker 存在且 current 为 probe 候选时，调用 rotation 闭包的 `test`；marker
   存在但 rotation 本已运行时不切换，保留 marker 待人工验收。Conduit 首次
   候选已验证真实回退分支；新版候选、断线和重启恢复尚未验证。

## 固定时刻保护和临时激活

在目标机按其 UTC 时钟计算 20 分钟后的绝对截止时间，先安装一次性 timer，读回
`ActiveState=active`、`NextElapseUSecRealtime`、`AccuracyUSec=1s`、
`Persistent=no` 与 `ExecStart`；距触发不足 19 分钟时重建窗口。再创建 root-only
marker，最后才运行 `sudo nixos-rebuild --no-reexec test --store-path <本机 outPath>`。
`test` 的 SSH 退出码 255 只能触发重连核对，不能判定成功或失败。

```bash
deadline=$(/run/current-system/sw/bin/date -u -d '+20 minutes' '+%Y-%m-%d %H:%M:%S UTC')
sudo /run/current-system/sw/bin/systemd-run --system \
  --unit=stage1-probe-ingress-rollback --on-calendar="$deadline" \
  --timer-property=AccuracySec=1s --timer-property=Persistent=no \
  --property=TimeoutStartSec=10min /run/stage1-probe-ingress-rollback.sh
systemctl show stage1-probe-ingress-rollback.timer \
  -p ActiveState -p NextElapseUSecRealtime -p AccuracyUSec -p Persistent
systemctl show stage1-probe-ingress-rollback.service -p ExecStart
sudo install -o root -g root -m 0600 /dev/null /run/stage1-probe-ingress-rollback.marker
```

切换后要求 current 精确等于本机 probe 候选，profile 和默认启动项仍指向表中
rotation 闭包，`booted` 仍为表中旧闭包；
SSH、Nginx、Xray、origin-proof 及 Hopper Gmail 均 active，probe 监听仅在
`127.0.0.1:18444`。旧订阅按上述 3/5 条逐字节复测，旧 Xray 身份与
`LoadCredential` 仍匹配。对新名称从本机及另一台主机用 `--resolve` 指向目标源站
测试 443 SNI、公开可信证书和 `/probe` 路由；无签名 `POST /probe` 必须返回 404，
合法签名请求须对指定对侧 origin 返回 200，响应 HMAC、nonce、sourceId 和
origin 与请求一致；错误签名、过期时间戳、越界地址须拒绝。反向测试原有 CDN
SNI、旧 `/proof` 和旧订阅，同时核对 probe 失败不会改变现用 v2 池或旧订阅。
新域名当前无 DNS，`--resolve` 仅检验源站入口，不能算公网验收。

所有检查须在 timer 到期至少 4 分钟前完成。只有两条 SSH 路径、全部旧服务和
订阅、新 probe 正反例均通过，才停止 timer，确认 inactive 后删除 marker；
随后再次复核 current、服务和旧订阅。任何候选身份、证书、SSH、服务、订阅、
SNI、HMAC 或剩余时间不达标时保留 timer 与 marker，立即在可登录时执行
`sudo /run/stage1-probe-ingress-rollback.sh` 或等待固定时刻回退。脚本只在精确
候选上调用持久 rotation 闭包的 `test`，核对 current/profile/default boot、
`booted` 与核心服务，并保留 marker 供人工复查旧订阅、
证书和流量；未完成复查不得称为恢复。timer 失败或主机失联需要人工恢复。

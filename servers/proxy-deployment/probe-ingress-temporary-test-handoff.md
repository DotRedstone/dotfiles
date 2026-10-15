# 双节点 probe ingress 临时测试交接

状态：2026-10-16。两台候选均只完成离线构建、目标 store 校验与 `dry-activate`；
**未执行本候选的 `test` 或 `switch`**。本轮没有修改 DNS、Cloudflare、路由器或旧订阅。
源码锚点为 `99bfdc1f7e754f16e706cf2046f3d27702fb3975`，在该源码上仅通过
`extendModules` 将对应主机的 `dot.services.proxyProbeIngress.enable` 设为 true；
ACME 仍关闭。回退脚本和本文的后续提交不改变 Nix 候选输入。入口与密钥边界见
[代理部署数据](./README.md#回源证明与可信探测)。

## 离线候选和运行基线

| 主机 | 顶层 deriver | 顶层 outPath | 当前临时运行闭包 | boot / 系统 profile |
| --- | --- | --- | --- | --- |
| Conduit | `/nix/store/4m8y9bl0j7jd7z20d8q0w82bncdrm29a-nixos-system-conduit-26.11.20260831.34ab990.drv` | `/nix/store/n2hdcalpxvl9zk85kap8z7nparmm8l3g-nixos-system-conduit-26.11.20260831.34ab990` | `/nix/store/fkq5h093an3qjynycv13awr76fdlra20-nixos-system-conduit-26.11.20260831.34ab990` | `8alf4971…` / `92j5wm1b…` |
| Hopper | `/nix/store/1fkrcil5czvvq63azxfp67q37ivlslh8-nixos-system-hopper-26.11.20260831.34ab990.drv` | `/nix/store/zylxw91hy1kyj12wi74m03as3ha9al41-nixos-system-hopper-26.11.20260831.34ab990` | `/nix/store/fznhzd6b9fxyc42zphwlq7sznp5045b6-nixos-system-hopper-26.11.20260831.34ab990` | `k69xg4y5…` / `w0aqhcla…` |

两台目标机 `nix-store -q --deriver <outPath>` 均与表中 deriver 相同，
`nix store verify --no-trust <outPath>` 均退出 0。两台
`sudo <outPath>/bin/switch-to-configuration dry-activate` 均退出 0，预计新增
`proxy/probe_env`、`proxy/probe_tls_cert`、`proxy/probe_tls_key` 三项运行 secret，
重启 `nginx.service` 并启动 `proxy-preferred-probe.service`。Conduit 与 Hopper 的
Nginx、Xray、origin-proof 正在运行；Hopper Gmail 正在运行；probe 当前 inactive。
两机 `current`、`boot`、`profile` 各不相同。`dry-activate` 后它们未改变。
这仅证明声明式差异和目标 store 可用，不证明证书渲染、TLS 路由或探测已运行。

## 逐机测试前置条件

先 Conduit，完成验收并观察至少 10 分钟后再考虑 Hopper。每台均要保留两条
SSH 会话，核对另一条重连路径；Hopper 没有已验证带外控制台，失联后的 timer
不能保证可执行，重启也不会延续临时 timer。任一时刻只能有一台处于本测试窗口。

1. 从上述固定源码重新求值，确认 deriver、outPath、目标 store 校验及三条系统闭包
   与表一致；确认无其他回退 timer/marker。旧 profile 与启动项不能作为本次临时
   测试的回退目标。检查旧 SSH、Nginx、Xray、origin-proof、Hopper Gmail，以及
   Conduit 3 条、Hopper 5 条旧订阅均为 HTTP 200 且正文与此前基线逐字节相同。
2. 在**目标机**用受限临时目录从目标 store 中的加密 SOPS 源渲染三项 probe 输入，
   不打印或传出私钥与 HMAC。核对静态全链与私钥匹配、SAN 覆盖本机 probe 名称、
   系统 CA 可验证链、有效期、Nginx 可读取证书与私钥，并核对环境只指向对侧
   origin。当前静态证书有效期至 2027-01-12；续期尚未确定。任何渲染或权限
   不符合预期时停止，不以 `dry-activate` 的“would add secrets”代替此检查。
3. 核对 [回退脚本](./scripts/probe-ingress-test-rollback.sh) 的 SHA-256 为
   `8ce294505f8e1056e006feeb65532df6b602071463ff19a14368725e223a979b`，
   安装在目标 `/run/stage1-probe-ingress-rollback.sh`，归属 root、权限 0700。
   marker 缺失且 current 为表中旧临时闭包时，脚本无变更返回 0；两台目标机
   已用脚本经 SSH stdin 演练此分支。真实回退分支、断线和重启恢复尚未验证。

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

切换后要求 current 精确等于本机 probe 候选，boot/profile 与表中旧值不变；
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
候选上调用旧临时闭包的 `test`，核对核心服务并保留 marker 供人工复查旧订阅、
证书和流量；未完成复查不得称为恢复。timer 失败或主机失联需要人工恢复。

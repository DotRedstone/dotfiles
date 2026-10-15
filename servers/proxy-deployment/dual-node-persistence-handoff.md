# 双节点持久切换交接

状态：2026-10-15。Conduit 与 Hopper 的 rotation 候选均已通过临时 `test`；
本文准备逐机持久 `switch`，但尚未执行。临时验收证据分别见
[第 1 阶段现场核对](./stage1-live-readiness-review.md) 与
[Hopper 临时测试交接](./hopper-rotation-test-handoff.md)。

## 精确运行与恢复锚点

| 主机 | 当前运行及拟持久化候选 | 当前启动闭包 | 当前系统 profile（回退目标） |
| --- | --- | --- | --- |
| Conduit | `/nix/store/fkq5h093an3qjynycv13awr76fdlra20-nixos-system-conduit-26.11.20260831.34ab990` | `/nix/store/8alf4971c77zpy5rb6rbdzbik12617pa-nixos-system-conduit-26.11.20260831.34ab990` | `/nix/store/92j5wm1b6jzjkv8rrx7xj9nahggqkglm-nixos-system-conduit-26.11.20260831.34ab990` |
| Hopper | `/nix/store/fznhzd6b9fxyc42zphwlq7sznp5045b6-nixos-system-hopper-26.11.20260831.34ab990` | `/nix/store/k69xg4y5d9qvp7w37p98q6vbfl0i1kgn-nixos-system-hopper-26.11.20260831.34ab990` | `/nix/store/w0aqhcla0ip3vp4mcwf6i8nvpdih575v-nixos-system-hopper-26.11.20260831.34ab990` |

两台旧 profile 的 `bin/switch-to-configuration`、`sw/bin/nix-env` 均存在，
`nix store verify --no-trust` 通过。候选与旧 profile 的 kernel、initrd 路径
逐字节相同；systemd unit 差异限于 Nginx 配置引用，以及候选新增的
`proxy-origin-proof.service`。这只能界定源码差异；持久 `switch` 仍会设置
系统 profile 和默认启动项，并可能重新运行激活脚本与服务。

Conduit 使用 BIOS GRUB，Hopper 使用 UEFI systemd-boot。旧启动闭包与旧系统
profile 不是同一路径，回退必须明确恢复上述旧 profile，不能用
`/run/booted-system` 代替。两台 SSH 均曾偶发超时，Hopper 没有已验证带外入口。
临时 systemd timer 不跨重启；切换后如 PID 1、网络或主机失效，也无法保证其运行。
真实持久切换与回退分支仍未实测。

## 一次性回退保护

[回退脚本](./scripts/dual-node-persistence-rollback.sh) 仅接受表中两台主机、
精确候选、旧 profile 和旧启动闭包。marker 不存在且 current 为候选、profile 为
旧值时只走 no-op。marker 存在且 current/profile 均为候选时，脚本将系统 profile
设回旧闭包，执行旧闭包的 `switch-to-configuration switch`；若 timer 到期时
profile 已是旧值但运行态仍为候选，也执行旧闭包切换。随后核对运行闭包、
profile、GRUB 或 systemd-boot 默认项、旧服务与旧订阅、Xray 凭据及旧身份，
并确认 rotation 与新 proof 服务撤下。若 marker 已建立但持久切换尚未开始，
timer 到期也会恢复旧运行闭包；这是本次窗口的保守回退边界。
任何路径、服务或订阅核对失败均保留 marker，不能据此宣称已恢复。

脚本 SHA-256 为 `320e9f32d5abd8e75906017c35cc49c6c5a81a80ae7350c3aa33e6ee2cfb71d9`。
目标机安装位置为 `/run/stage1-persistence-rollback.sh`，root:root、0700。
`sh -n`、`shellcheck` 与两台无 marker 的直接 no-op 已通过。固定时刻 timer
分别于 Conduit 的 23:54:52、Hopper 的 23:55:53（UTC+8）执行同一脚本，
均记录 no-op、服务退出码 0，timer 卸载，current/profile 与 marker 未改变。
两台启动项解析器均以 root 权限对现有旧默认项通过只读校验。
这只验证调度和无变更分支；真实回退分支及失联恢复尚未实测。真实切换前必须
重新核对脚本 hash、权限和现场锚点。

## 逐机执行与验收

只在已 SSH 登录的**目标主机**执行命令，先 Conduit，完成验收并观察至少 10 分钟，
再对 Hopper 重复。每台切换前重新核对表中 current、boot、profile、候选 store、
旧订阅、运行凭据和 SSH；确认没有其他 marker/timer。保留第二条 SSH 会话。

在目标机从其 UTC 时钟计算固定截止时间，先安装回退 timer，读回
`ActiveState=active`、`NextElapseUSecRealtime`、`AccuracyUSec=1s`、
`Persistent=no` 与 `ExecStart`；确认距触发至少 19 分钟后创建 root-only marker：

```bash
deadline=$(/run/current-system/sw/bin/date -u -d '+20 minutes' '+%Y-%m-%d %H:%M:%S UTC')
sudo /run/current-system/sw/bin/systemd-run --system \
  --unit=stage1-persistence-rollback --on-calendar="$deadline" \
  --timer-property=AccuracySec=1s --timer-property=Persistent=no \
  --property=TimeoutStartSec=10min /run/stage1-persistence-rollback.sh
systemctl show stage1-persistence-rollback.timer \
  -p ActiveState -p NextElapseUSecRealtime -p AccuracyUSec -p Persistent
systemctl show stage1-persistence-rollback.service -p ExecStart
sudo install -o root -g root -m 0600 /dev/null /run/stage1-persistence-rollback.marker
```

**在 Conduit 上**执行一次：

```bash
sudo nixos-rebuild --no-reexec switch --store-path \
  /nix/store/fkq5h093an3qjynycv13awr76fdlra20-nixos-system-conduit-26.11.20260831.34ab990
```

Conduit 全部验收通过、停止 timer 并清除 marker 后，等待至少 10 分钟。
**在 Hopper 上**另起窗口，重复安装保护，再执行一次：

```bash
sudo nixos-rebuild --no-reexec switch --store-path \
  /nix/store/fznhzd6b9fxyc42zphwlq7sznp5045b6-nixos-system-hopper-26.11.20260831.34ab990
```

SSH 退出码 255 不等于切换失败；重连核对 current、profile、timer、marker 和 journal。
每台均要求 current/profile 指向候选，`/run/booted-system` 在重启前仍为旧值；
Conduit 核对 `/boot/grub/grub.cfg` 的默认 `NixOS` 项指向候选；Hopper 核对
`/boot/loader/loader.conf` 的 `default` 条目及对应 entry 的 `init=` 指向候选。
切换前 Conduit 的 GRUB 配置含旧 profile、不含候选；Hopper 默认 entry 指向旧
profile，候选 entry 尚不存在。继续核对 SSH、Nginx、Xray、proof，Hopper 另查
Gmail 健康与只读 API。Xray 运行凭据须与 SOPS 渲染逐字节相同并含旧身份和新
rotation；Conduit 三条、Hopper 五条旧订阅须分别 HTTP 200 且正文不变。
proof 的有效/无效令牌分别返回 200/404、HMAC 正确；从另一节点对新旧 Reality、
旧 Vision 和 CDN 做真实 HTTPS 出口测试。验收在 timer 到期前至少 4 分钟结束。

全部通过后，先 `sudo systemctl stop stage1-persistence-rollback.timer`，确认
timer inactive，才删除 `/run/stage1-persistence-rollback.marker`；复核
current/profile、默认启动项、服务和旧订阅。失败时保留 timer/marker，能登录且
current/profile 均为候选时可手动执行
`sudo /run/stage1-persistence-rollback.sh`，然后核对旧 profile 与旧路径。
timer 或脚本失败时仍需人工恢复；未验证重启后的实际启动行为，不通过重启测试来
推断安全性。

本阶段不修改 DNS、Cloudflare Worker、路由器、旧订阅源或旧身份；两台持久化
也不等于公网新入口已发布。

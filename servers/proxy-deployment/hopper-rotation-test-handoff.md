# Hopper rotation 临时测试交接

状态：2026-10-15。本文只覆盖 Hopper 已构建候选的临时 `test`。尚未执行候选激活、
持久 `switch`、DNS/Worker/路由器变更或旧身份撤销。Conduit 仍运行此前的临时测试闭包；
不能把两台主机的构建结果视为双节点部署完成。阶段证据见
[第 1 阶段现场核对](./stage1-live-readiness-review.md)。

## 精确候选与现场边界

- 候选源码锚点：`3b4d6013888ceb1e3176973c8569c7c6e03e7eed`。其后的工作树提交
  只改阶段文档和本文所附的一次性回退脚本；激活前须重新求值，确认 deriver 未变。
- `proxyStack` 锁定 revision `5393d0e1bffd3406b62b09269b54fd7434778f3e`，
  NAR `sha256-0XNue1CC3fs0kTAsQB/zSs64Su+8y/UQ2poi+0F1E+g=`；`edgeProxyWorker`
  锁定 `538d974998f217a7a10cd8a178b62e82d44fcb89`，
  NAR `sha256-8IzmqzVJrw/oMnT0+/E2tc1lj96QLDImdKmkFuy5f3I=`。
- 顶层 deriver：`/nix/store/zih3d013lk3rd391j0wqk9s9gxk4arwh-nixos-system-hopper-26.11.20260831.34ab990.drv`。
  候选输出：`/nix/store/fznhzd6b9fxyc42zphwlq7sznp5045b6-nixos-system-hopper-26.11.20260831.34ab990`。
  目标端 deriver 与求值一致，NAR `sha256-UaZ+LG6l9SLA32o0PeK2lXSLa/L8RiIrHELzW7nkV2I=`，
  NAR size `365744`；目标顶层内容与递归闭包有效性校验退出码均为 0。
- 当前运行闭包：`/nix/store/dv9bxyww51y3mxv55vbvrsn8qhv6gnp1-nixos-system-hopper-26.11.20260831.34ab990`。
  启动闭包为 `k69xg4y5…`，系统 profile 为 `w0aqhcla0…`；三者不同，后两者在本次
  临时 `test` 中不得改变。失败回退应回到当前运行闭包 `dv9bxyww…`，不能误用启动闭包。
- 候选加密 `hopper.yaml` 在目标 store 与本地文件的 SHA-256 均为
  `f577f7d9677954ce0c89222cc08ee771ae78a6032cc4a42bc3c281354401f907`；本地
  SOPS 解密确认旧 UUID、rotation UUID、Reality 密钥与 WebSocket 路径均存在。声明式
  `rotation.enabled` 和 `xray/managed_rotation_uuid` 引用均为 true。激活后仍须核对
  SOPS 实际渲染与 Xray `LoadCredential`，不能以密文存在代替运行态证明。
- 候选与当前的 `sshd`、Nginx、Xray、Gmail、订阅检查 unit 逐字节相同；
  `proxy-origin-proof.service` 的 `ExecStart` 源码 store 路径改变，验收时须重测 proof。
  当前 5 条旧订阅均为 HTTP 200 且与 SOPS 正文逐字节相同；旧 primary、Vision 和 CDN
  已从 Conduit 独立路径各对两个 HTTPS 目标测试 2 次，全部成功。

## 风险与回退边界

Hopper 没有已验证的带外控制台。SSH 曾出现 banner 超时；直连和经 Conduit 跳转可作
两条重连路径，但都依赖 Hopper 的 SSH 与网络。旧启动项和系统 profile 保留；重启
具体选择哪个旧闭包尚未验证，当前也没有可验证的远程重启保障。临时 systemd timer
不跨主机重启。

回退脚本为 [scripts/hopper-rotation-rollback.sh](./scripts/hopper-rotation-rollback.sh)，
只匹配上述旧闭包和候选闭包。它在 marker 缺失且 current 为旧闭包时显式 no-op；真实
回退仅在 marker 存在且 current 为精确候选时执行旧闭包的
`bin/switch-to-configuration test`。之后核对当前闭包、关键服务、SOPS 渲染配置与
Xray `LoadCredential`，必要时重启 Xray；确认 rotation 已撤下才删除 marker。
切换脚本失败、当前闭包不符或服务验收失败时保留 marker 并返回错误，不能宣称自动恢复。

脚本已通过 `sh -n`、`shellcheck`，本地 SHA-256 为
`f13a37566da41a71e51dd06b2a17004e378ce1126262dfd18d5adf4f21a72e6c`。
目标端安装命令返回 0，路径为 `/run/stage1-hopper-rotation-rollback.sh`；读回确认
root 归属、0700 权限与上述 SHA-256。无 marker 时手动执行返回 0，Xray PID 与
current 均未变化。先前遗留的
`/run/stage1-hopper-rollback.sh` 是另一候选的旧脚本，不得复用。

固定时刻无害 timer probe 已创建，读回 `AccuracyUSec=1s`、`Persistent=no` 和预定时刻；
journal 确认它在预定秒执行且成功。随后以同样固定时刻 timer 调度上述回退脚本，
在 marker 缺失且 current 为旧闭包时记录 `rollback rehearsal: no-op branch executed`，
服务成功退出、timer 自动卸载，current 与 marker 均未改变。这只证明调度与 no-op
分支，不证明真实回退或主机失联恢复。

## 获得风险授权后的单机执行顺序

1. 重新核对 Git/Flake/目标 store/密钥文件/旧订阅及三种系统闭包；任何路径或 hash
   不符时停止。保持另一路经 Conduit 的 SSH 会话；核对没有现存的回退 marker/timer。
   检查 `/run` 脚本的 SHA、权限及 no-op 分支。如当前运行基线已改变，重新做短时固定
   时刻 no-op timer 演练。

   ```bash
   git diff --name-only 3b4d6013888ceb1e3176973c8569c7c6e03e7eed..HEAD
   nix eval --raw path:./servers#nixosConfigurations.hopper.config.system.build.toplevel.drvPath
   nix eval --raw path:./servers#nixosConfigurations.hopper.config.system.build.toplevel.outPath
   # 以下命令在 Hopper 执行；不得把当前、boot、profile 当成同一闭包。
   readlink -f /run/current-system
   readlink -f /run/booted-system
   readlink -f /nix/var/nix/profiles/system
   nix-store -q --deriver /nix/store/fznhzd6b9fxyc42zphwlq7sznp5045b6-nixos-system-hopper-26.11.20260831.34ab990
   nix store verify --no-trust /nix/store/fznhzd6b9fxyc42zphwlq7sznp5045b6-nixos-system-hopper-26.11.20260831.34ab990
   sudo sha256sum /run/stage1-hopper-rotation-rollback.sh
   sudo stat -c '%U %a' /run/stage1-hopper-rotation-rollback.sh
   ```
2. 从 Hopper 的 UTC 时钟计算绝对截止时间并先安装回退 timer。**在候选激活前**读回
   `ActiveState=active`、`NextElapseUSecRealtime` 与脚本命令，确认距当前不少于
   19 分钟、`AccuracyUSec=1s`、`Persistent=no`；然后创建 root-only marker。

   ```bash
   deadline=$(/run/current-system/sw/bin/date -u -d '+20 minutes' '+%Y-%m-%d %H:%M:%S UTC')
   sudo /run/current-system/sw/bin/systemd-run --system \
     --unit=stage1-hopper-rotation-rollback \
     --on-calendar="$deadline" \
     --timer-property=AccuracySec=1s \
     --timer-property=Persistent=no \
     --property=TimeoutStartSec=10min \
     /run/stage1-hopper-rotation-rollback.sh
   systemctl show stage1-hopper-rotation-rollback.timer \
     -p ActiveState -p NextElapseUSecRealtime -p AccuracyUSec -p Persistent
   sudo install -o root -g root -m 0600 /dev/null /run/stage1-hopper-rotation-rollback.marker
   ```

3. 仅执行一次临时激活，不更新系统 profile：

   ```bash
   sudo nixos-rebuild --no-reexec test --store-path \
     /nix/store/fznhzd6b9fxyc42zphwlq7sznp5045b6-nixos-system-hopper-26.11.20260831.34ab990
   ```

   SSH 退出码 255 不能直接判断激活失败。立即通过两条连接路径核对 current、timer、marker、
   关键服务与 journal。验收应在触发前至少 4 分钟结束；若无法登录，等待固定截止时间
   触发，不提前撤除回退保护。
4. 在 timer 到期前验证：current 为候选、boot/profile 不变；`sshd`、Nginx、Xray、
   `proxy-origin-proof`、Gmail active；Xray `LoadCredential` 与 SOPS 渲染逐字节相同，
   同时加载旧 primary/Vision、guest/canary 和新 rotation；五条旧订阅逐字节不变；
   `/proof` 的有效/无效令牌分别为 200/404 且 HMAC 正确；Gmail 健康和只读 API
   保持正常。再从 Conduit 独立路径对旧/新 Reality、旧 Vision、旧 CDN 各做有限的
   HTTPS 实际出口测试。任何一项失败均保留 timer 与 marker，观察真实回退及旧路径恢复。
5. 仅当全部验收通过且 timer 尚有足够时间时停止 timer，再清除 marker；复核 timer
   inactive/not-found、current 仍是候选、boot/profile 仍旧、服务和订阅正常。保留
   `/run` 回退脚本至本次窗口结束。此时仍是临时 `test`，重启后的具体旧启动项尚未验证。

   ```bash
   sudo systemctl stop stage1-hopper-rotation-rollback.timer
   systemctl show stage1-hopper-rotation-rollback.timer -p ActiveState -p LoadState
   sudo /run/current-system/sw/bin/rm -f /run/stage1-hopper-rotation-rollback.marker
   ```

若候选验收失败但 SSH 仍可用，可在 marker 存在、current 为精确候选时手动执行
`sudo /run/stage1-hopper-rotation-rollback.sh`，然后核对旧闭包、旧订阅和服务；timer
可留待截止时再次进入 no-op 分支。脚本失败或两条 SSH 路径均失联时，不手动撤除
timer/marker；等待 timer 的 journal 与现场状态。若 PID 1 或网络完全失效导致 timer
也无法运行，目前没有已验证的带外恢复路径。

本交接不授权持久 `switch`、公网 DNS/Cloudflare 发布、路由器主组切换、Target 变更或
撤销任何旧身份。真实 Hopper 临时激活仍需在无已验证带外恢复入口的风险下取得明确授权。

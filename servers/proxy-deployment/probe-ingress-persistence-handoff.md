# 双节点 probe ingress 持久切换交接

状态：2026-10-16。两台 probe ingress 已分别通过临时 `test` 和持久 `switch`，
即时验收通过；Hopper 的 10 分钟观察仍待 05:00:35 CST 后由主会话复核。
临时验收范围见[临时测试交接](./probe-ingress-temporary-test-handoff.md)。
Cloudflare、DNS、路由器和旧订阅不在此切换范围内。

## 精确闭包与影响

| 主机 | 持久 rotation 基线与回退目标 | 已验 probe 候选 | 未重启前的 booted |
| --- | --- | --- | --- |
| Conduit | `/nix/store/fkq5h093an3qjynycv13awr76fdlra20-nixos-system-conduit-26.11.20260831.34ab990` | `/nix/store/73qxjfv9l6fjp73fvqpi31a02gnnvwd4-nixos-system-conduit-26.11.20260831.34ab990` | `/nix/store/8alf4971c77zpy5rb6rbdzbik12617pa-nixos-system-conduit-26.11.20260831.34ab990` |
| Hopper | `/nix/store/fznhzd6b9fxyc42zphwlq7sznp5045b6-nixos-system-hopper-26.11.20260831.34ab990` | `/nix/store/irwzjkl39v1ra9la699smvymkxpbgzz8-nixos-system-hopper-26.11.20260831.34ab990` | `/nix/store/k69xg4y5d9qvp7w37p98q6vbfl0i1kgn-nixos-system-hopper-26.11.20260831.34ab990` |

持久切换后，两台 current、系统 profile 与默认启动项均指向各自 probe 候选；
`/run/booted-system` 仍是表中旧闭包，尚未重启。源码提交 `55479d9` 在两台
`cross-probe.nix` 明确启用入口；普通 `servers/flake.nix` 求值分别精确得到表中
Conduit `73qxjfv…` 与 Hopper `irwzjkl…` 输出路径。求值匹配不代替切换后的
服务与流量验收，也不证明重启或真实回退分支。Conduit 使用 GRUB，Hopper 使用
systemd-boot；Hopper 无已验证的带外控制台，timer 不跨重启，失联后不能保证
自动恢复。

两机持久切换的即时验收均通过：current/profile/default 与候选一致，旧代理、
订阅及服务和新 probe 入口保持可用；一次性回退 timer 已停止，marker 已清除。
Conduit 的切换后观察已完成；Hopper 的 10 分钟观察结论尚待上述时刻后复核，
不能将即时验收写成观察完成。两机均未重启，重启后启动行为仍未验证。

## 一次性回退保护

[回退脚本](./scripts/probe-ingress-persistence-rollback.sh) 只接受上述主机和精确
闭包，不使用会撤销 rotation 身份的旧持久切换回退脚本。它要求 booted 与表中
一致，current/profile/default 各自只指向 rotation 或 probe。marker 缺失、
timer inactive，且 current 为 probe、profile/default 为 rotation 时只执行
no-op。marker 存在时，如 profile 已变为 probe，先将系统 profile 设回 rotation，
然后运行 rotation 闭包的 `switch-to-configuration switch`，恢复运行闭包和默认
启动项；即使切换尚未开始，也保守地执行 rotation 的 switch。

脚本随后核对 current、profile、默认启动项和 booted，检查 SSH、Nginx、Xray、
origin-proof、订阅检查服务与 Hopper Gmail；确认 probe 停止、Xray 运行凭据与
渲染配置一致且 rotation/canary 身份仍在，并逐字节核对 Conduit 3 条、Hopper
5 条旧订阅。成功后仍保留 marker，等待人工复核双 SSH 路径、Gmail API、proof、
旧代理真实出口和外部订阅路径，再停止 timer 并删除 marker。脚本出错或这些
复核未通过时不得称为恢复。

脚本 SHA-256 为 `1a499025e624badcaeaffa90071ee850cfbccf3499aded501228ff2c3a6a6097`。
`sh -n`、`shellcheck` 与两台隔离夹具中的无 marker
no-op 模拟已通过；模拟使用假 current/profile/default/booted 和 inactive timer，
没有访问或更改远端主机。真实回退、失联恢复及重启后的默认启动行为未验证。

## 逐机执行与后续核对

以下是本次逐机持久切换的保护与验收步骤留档，不得据此重复运行已完成的
`switch`。当时先 Conduit、后 Hopper；每台开始前
重新核对 Git 源码、候选 deriver/outPath、目标 store 完整性、表中三种闭包、
默认启动项、旧服务/订阅、运行凭据、SSH 双路径和回退脚本 SHA/权限；确认无
其他 marker/timer。目标机安装脚本到
`/run/stage1-probe-persistence-rollback.sh`，root:root 0700，读回 SHA；先在
无 marker 状态演练 no-op，再建立固定 UTC 截止时刻的 20 分钟 timer，读回
`ActiveState=active`、预定时刻、`AccuracyUSec=1s`、`Persistent=no` 和精确
`ExecStart`。剩余不足 19 分钟时重建窗口。然后创建 root:root 0600 marker，
才对表中本机 probe 候选执行一次 `nixos-rebuild --no-reexec switch --store-path`。
不要重用临时测试 timer 或 marker。

切换后要求 current/profile/default 都指向本机 probe，booted 在重启前保持表中
旧值；确认两条 SSH、旧服务与订阅、运行凭据、旧代理出口、proof、Hopper Gmail、
新 probe SNI/TLS/HMAC 正反例均与临时测试一致。所有验收须在 timer 到期至少
4 分钟前完成。SSH 退出码 255 只能触发重连与状态核对。任何路径、服务、证书、
旧订阅、代理出口或剩余时间不达标时保留 timer/marker；可登录时执行本脚本或
等待固定时刻回退，并完整复核 rotation。只有全部验收通过，才停止 timer、
确认 inactive、删除 marker，再复核 profile/default、服务和订阅。后续仍需完成
Hopper 观察结论；重启测试不能替代本次回退保护，且本次未执行重启。

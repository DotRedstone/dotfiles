# Hopper Restic 备份运行手册

## 已部署拓扑

```text
Hopper service data
  └─ logical database exports + application data
       └─ local Restic repository on Hopper
            └─ Restic snapshot copy
                 └─ dedicated Cloudflare R2 repository
```

本地仓库用于较快恢复；R2 是独立的异地副本。两端都保存 Restic 加密快照，不能用文件
管理器直接读取。仓库口令和 R2 最小权限凭据均由 Hopper 的 SOPS 密文配置在运行时生成，
不应复制到 Git、笔记或聊天记录。

## 覆盖范围

- OpenList 数据目录；
- Navidrome 数据目录及音乐库；
- RustFS 对象数据；
- MySQL、PostgreSQL、MongoDB 的逻辑导出；
- Redis 的 RDB 导出。

`conduit` 已接入同一接收端，但使用独立 SFTP 密钥、仓库口令与 R2 前缀；当前保护其
EasyTier 运行状态。它每天先写入 Hopper 的 `conduit` 仓库，随后由 Hopper 复制到 R2。

`repeater` 已接入每日新增备份：Vaultwarden、Komari、EasyTier、Nginx 证书和 EasyTier
密钥材料由 Hopper 以专用受限 SSH 密钥拉取。每次运行仅短暂停止 Vaultwarden 与 Komari
写入服务以获得 SQLite 一致性，然后在同一清理保护中立即启动它们。导出写入独立本地
Restic 仓库、镜像至 R2，R2 每月抽样校验。此前从 R2 选择性还原 Vaultwarden 数据库的
恢复演练仍然有效。

`target` 已收编并接入独立仓库：当前备份 EasyTier 持久状态；其反代规则来自 Nix
配置，本身不需要作为运行时数据备份。

数据库不直接复制在线数据目录。MongoDB 的备份/恢复角色会由 NixOS 单元在备份前校正，
其口令不进入进程命令行或仓库快照。

## 运行策略

- 每日 03:30 起（最多随机延后 30 分钟）：先创建 Hopper 本地快照，再复制到 R2；
- 保留 14 个日快照、8 个周快照和 12 个月快照；
- 每月运行一次 R2 仓库抽样完整性检查，读取 5% 数据包；
- 首次与每次部署后，执行一次受控恢复演练到临时目录，确认导出的数据库文件可恢复。

相关单元：

```text
restic-backups-hopper-local.service
restic-mirror-hopper-to-r2.service
restic-check-hopper-r2.service
restic-mirror-conduit-to-r2.service
restic-check-conduit-r2.service
restic-export-repeater.service
restic-backups-repeater-import.service
restic-mirror-repeater-to-r2.service
restic-check-repeater-r2.service
restic-mirror-target-to-r2.service
restic-check-target-r2.service
```

日常排障只查看状态和日志，不要在命令中打印或粘贴密钥：

```bash
systemctl status restic-mirror-hopper-to-r2.service
journalctl -u restic-mirror-hopper-to-r2.service --since today
```

## 将其他服务器接入

Hopper 已预置仅 SFTP 的 `restic` 接收账户：它被 chroot 到专用仓库目录、禁止 shell、TTY
和端口转发；在尚未添加源服务器公钥前，该账户不能登录。接入每台源服务器时必须分别完成：

1. 生成独立 SSH 密钥和独立 Restic 仓库口令；
2. 将其公钥加入 Hopper 接收账户，将私钥和口令加密进该源服务器的 SOPS 文件；
3. 先为数据库生成一致性导出，再备份到该服务器专属的 Hopper 仓库路径；
4. 在 Hopper 为该仓库创建独立 R2 前缀，并通过 `restic copy` 复制快照；
5. 做一次目标端恢复演练后才启用定时器。

不要让多台源服务器共享同一个 Restic 仓库或 SSH 私钥。

## Repeater 收编前的边界

目前不能为 `repeater` 直接部署一份残缺的 NixOS 配置：那会有停止正在运行的
Vaultwarden 或 Komari 的风险。Hopper 的受控导出已经每日生成新快照，但它是过渡方案。
完成硬件、网络和服务源码收编后，再将同一套“短暂停写 → 备份数据库与附件 → 立即启动”
逻辑迁回 Repeater 的 `resticClient`，并撤除 Hopper 的拉取密钥。

## 仍需补上的第三副本

当前是“两份、两个位置”：Hopper 本地 + R2。它不是完整的 3-2-1。待 NAS 或另一家对象
存储确定后，应使用另一套凭据和另一份仓库口令再复制关键快照；不要把本机 Restic 仓库
整体再用 Restic 打包备份。

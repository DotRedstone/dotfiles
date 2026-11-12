# repeater 收编卡

## 已确认

- 主机名为 `repeater`，当前运行 NixOS 26.05，SSH 可用，`dot` 可无密码 sudo。
- 本机未发现该主机的 Flake 源码；它不能被当前 `servers/flake.nix` 重建。
- 迁移前已对 EasyTier、Vaultwarden、OpenResty、Komari 生成并验证 Age 加密归档。
- 已额外创建独立 Restic 本地/R2 迁移快照；从 R2 选择性还原 Vaultwarden 数据库已通过。
- 在完整主机源码恢复前，Hopper 以受限、固定 host key 的专用 SSH 密钥每日拉取选定数据。
  拉取时仅短暂停止 Vaultwarden 与 Komari 写入服务，导出后无论成功或失败都会立即启动它们；
  随后生成 Hopper 本地快照、镜像至 R2，并按月抽样校验。这已经提供每日新增恢复点。

## AstrBot 原生服务过渡

- AstrBot 4.28.2 的通用包与服务模块由独立 `astrbot-nix` 项目维护。当前在本机使用
  固定 Nix 闭包生成的专用用户 systemd user unit，并已启用 linger；这是服务级过渡，
  不是 `servers/flake.nix` 对整机的接管。
- 原 Docker 容器已停止并关闭自动重启，容器和镜像仍保留。应用数据继续留在本机的
  私有目录；切换前的停写快照已完成归档及 SQLite 完整性校验，恢复说明保存在本机
  受限位置。该快照不属于上述每日拉取备份范围。
- 回环 WebUI 与既有 Nginx 反代已返回正常响应；唯一启用的 QQ 官方平台使用出站
  WebSocket，已观察到连接启动及远端连接。真实 QQ 消息收发、插件业务请求与整机
  重启后的自动恢复仍待验证。旧容器和快照应在这些验收完成前保留。
- 临时自动回退曾因脚本调用了错误的 `sudo` 路径而失败；其进程检查阻止了旧容器与
  原生实例同时启动。现有手动回退步骤已在本机受限记录中修正。

## AstrBot 统一通知接入边界

作业、网盘、音乐三个业务插件继续独立维护；统一通知由第四个插件
`astrbot-plugin-notification-hub` 承担。业务生产者只提交不含收件人的事件，
通知中心负责认证、静态路由、去重、持久化和投递状态。接入通知中心不自动迁移
现有业务的发送路径，避免重复发送或影响原有命令。

| 维护范围 | 归属 |
| --- | --- |
| AstrBot 通用包与服务模块 | 独立 `astrbot-nix` 项目 |
| 通知协议、客户端与插件实现 | 独立 `/home/dot/Projects/astrbot-plugin-notification-hub` 项目，以其 README 为准 |
| 固定版本引用、服务账号、目录权限、密钥引用与主机实例 | 完成收编后由本仓库 `servers/hosts/repeater/` 承担 |
| 来源路由、生产者凭据与运行数据 | 私有部署配置及受限持久目录，不写入通用源码或 Nix store |

当前服务器 Flake 未引用上述两个项目，也没有 Repeater 的可部署输出。本节记录
接入约束，不表示通知插件已经安装、启用或通过真实 QQ 验收。收编前不添加占位
主机模块，也不以整机部署方式替换现有服务级过渡。

后续接入需满足以下条件：

1. 固定并审查服务包与插件修订，盘点现有三个业务插件的版本、配置和数据，
   保留停写一致性备份及恢复步骤；安装通知中心时保持默认关闭，不覆盖其他插件。
2. 按实际服务账号选择 `socket_path` 和持久化 `state_db`。当前是 systemd user
   服务，不能直接假定插件默认的 `/run/astrbot`、`/var/lib/astrbot` 可写；检查父目录、
   socket 与 SQLite sidecar 的权限，并确保状态库不会随运行时目录清理而丢失。
3. 通过受限私有配置提供 `source_targets_json` 和 `producer_tokens_json`，真实
   UMO 从目标会话核实。当前插件仅支持同机 Unix socket；异机生产者需要先设计
   独立的受控传输，不为此开放公网 TCP 或放宽 socket 权限。
4. 分别验证插件加载、同机连接权限、认证与去重，再在获准的目标会话验证真实
   投递及原有三个业务。`accepted` / `duplicate` 是持久接收回执，`submitted`
   只表示 AstrBot 调用返回；这些状态均不能代替 QQ 客户端显示验收。
5. 遇到 `unknown` 时暂停该来源并人工核对，保留生产者待发事件与去重数据库。
   回退时停用通知中心、恢复此前固定版本和私有配置；不清空状态库或自动重放，
   不因回退通知插件而同时启动旧容器与原生 AstrBot 实例。

## 收编前必须重新盘点

- 磁盘、分区、UEFI/BIOS、网络接口、IPv4/IPv6 及云厂商恢复路径；
- 当前 EasyTier、反代、Vaultwarden、Komari 的单元、端口、数据路径和证书；
- Vaultwarden 数据库和附件的一致性备份方式；
- 需要保留的 SSH host key 与客户端登录密钥。
- 将 AstrBot 专用用户、user unit、运行数据、凭据引用与恢复步骤纳入完整主机源码；
  先验证新的 NixOS 配置，再替换服务级过渡方案。

## 目标

创建 `hosts/repeater/`、`secrets/repeater.yaml` 和一份恢复文档后，才将其加入 Flake。
在此之前，不向该主机推送不完整的系统配置；持续备份由 Hopper 的声明式受控导出作业承担。

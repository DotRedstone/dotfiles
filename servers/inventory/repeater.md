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

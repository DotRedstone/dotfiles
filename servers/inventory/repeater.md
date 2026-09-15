# repeater 收编卡

## 已确认

- 主机名为 `repeater`，当前运行 NixOS 26.05，SSH 可用，`dot` 可无密码 sudo。
- 当前没有 failed systemd unit。
- 本机未发现该主机的 Flake 源码；它不能被当前 `servers/flake.nix` 重建。
- 迁移前已对 EasyTier、Vaultwarden、OpenResty、Komari 生成并验证 Age 加密归档。
- 已额外创建独立 Restic 本地/R2 迁移快照；从 R2 选择性还原 Vaultwarden 数据库已通过。
- 在完整主机源码恢复前，Hopper 以受限、固定 host key 的专用 SSH 密钥每日拉取选定数据。
  拉取时仅短暂停止 Vaultwarden 与 Komari 写入服务，导出后无论成功或失败都会立即启动它们；
  随后生成 Hopper 本地快照、镜像至 R2，并按月抽样校验。这已经提供每日新增恢复点。

## 收编前必须重新盘点

- 磁盘、分区、UEFI/BIOS、网络接口、IPv4/IPv6 及云厂商恢复路径；
- 当前 EasyTier、反代、Vaultwarden、Komari 的单元、端口、数据路径和证书；
- Vaultwarden 数据库和附件的一致性备份方式；
- 需要保留的 SSH host key 与客户端登录密钥。

## 目标

创建 `hosts/repeater/`、`secrets/repeater.yaml` 和一份恢复文档后，才将其加入 Flake。
在此之前，不向该主机推送不完整的系统配置；持续备份由 Hopper 的声明式受控导出作业承担。

# target 收编卡

## 已确认

- 主机名为 `target`，当前运行 NixOS 26.05，SSH 可用，`dot` 可无密码 sudo。
- 当前没有 failed systemd unit。
- `hosts/target/` 已收编到当前 `servers/flake.nix`，包含硬件、SSH、防火墙、EasyTier 和反代。
- 已接入独立 Restic SFTP 仓库：每日将 EasyTier 持久状态备份到 Hopper，之后镜像至 R2，
  并每月进行异地抽样完整性校验。

## 变更前必须重新盘点

- 硬件、磁盘、启动方式和云平台网络；
- 正在运行的服务、端口、服务数据和外部依赖；
- 是否属于国内 EasyTier 网络、是否承载反代或代理入口；
- 需要进入 SOPS 的密钥，以及恢复测试所需的最小数据集。

## 后续规则

后续新增需要持久化的服务时，应把其数据路径显式加入 `resticClient.paths`，并先完成一次
恢复演练；不要把反代运行时缓存误当成需要备份的数据。

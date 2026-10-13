# target 收编卡

## 已确认

- 主机名为 `target`，2026-10-13 运行 `26.11.20260831.34ab990`，
  `system.stateVersion` 为 `26.05`；SSH 可用，`dot` 可无密码 sudo。
- 当前没有 failed systemd unit。
- `hosts/target/` 已收编到当前 `servers/flake.nix`，包含硬件、SSH、防火墙、EasyTier 和反代。
- 已接入独立 Restic SFTP 仓库：每日将 EasyTier 持久状态备份到 Hopper，之后镜像至 R2，
  并每月进行异地抽样完整性校验。

## 优选探测入口现状

2026-10-13 的只读核对确认，配置的公网 SSH 地址可连至 `target`，Nginx 运行中，
但没有 `80/443` 监听或 TLS 虚拟主机；当前主机防火墙规则也未放行这两个端口。
Conduit 与 Hopper 从各自公网连接该地址的 `80/443` 均超时。工作站网络受 TUN
影响，其本地 TCP 连接结果不用于判定公网可达性。上述证据不能区分腾讯云安全组
是否同时阻断了端口。本机及 Target 均未发现可用的腾讯云只读 CLI 凭据。
Target 元数据返回实例 ID `ins-8ljfjhu7`；须在腾讯云 CVM 控制台按该 ID
找到所属地域、关联的全部安全组，核对其入站 TCP 443 的来源、动作和规则顺序，
并使用“实例端口验通”检查 443。也应确认该实例的公网地址与 SSH 配置一致。
此处只记录核对对象，不修改安全组。

当前主机无 ACME 单元或证书目录，SOPS 已登记独立 DNS-01 token 和探测环境；
尚未部署证书与服务。密钥来源、轮换和启用边界见下述代理部署说明。
Cloudflare 上拟用于隔离探测的 `probe-v2-canary.dotdot.ggff.net` 尚无 DNS 记录。
锁定 Worker 源码已在 Flake 中预接入 Target 的默认关闭模块。DNS-01/TLS 入口的
准备及凭据边界见 [代理部署数据](../proxy-deployment/README.md#target-探测入口准备)。
关闭状态的求值未生成探测服务，也未改变防火墙或 Nginx。源码求值与 SSH 核对
不证明公网 HTTPS 探测可用。

## 变更前必须重新盘点

- 硬件、磁盘、启动方式和云平台网络；
- 正在运行的服务、端口、服务数据和外部依赖；
- 是否属于国内 EasyTier 网络、是否承载反代或代理入口；
- 需要进入 SOPS 的密钥，以及恢复测试所需的最小数据集。

## 后续规则

后续新增需要持久化的服务时，应把其数据路径显式加入 `resticClient.paths`，并先完成一次
恢复演练；不要把反代运行时缓存误当成需要备份的数据。

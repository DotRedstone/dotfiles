# gcp-free 状态卡

`gcp-free` 已有完整 Flake 配置、SOPS 密文和迁移归档，但当前 SSH 配置中的 HostName
没有被解析为有效地址，因此运行状态未复核。

恢复连接后，先确认新公网 IP、GCE Guest Agent、月流量守卫、EasyTier 和 Xray；如果
该免费实例已不再保留，则在 Git 中归档其主机配置和迁移备份，而不是继续让失效别名
看起来像可部署目标。

# NixOS Servers

这是独立于桌面配置的云服务器 Flake，仓库路径为
`/home/dot/.dotfiles/servers`。共享基线与每项服务都拆成单一职责模块，密钥由
SOPS 加密后随 Git 配置保存。

开始修改前先阅读 [AGENTS.md](./AGENTS.md)。目录职责见
[hosts/README.md](./hosts/README.md) 与 [modules/README.md](./modules/README.md)；它们
解释“主机组装层”和“可复用服务模块”应如何分工。

## 主机与纳管状态

`hosts/` 只放能够由此 Flake 重建的主机；不要把“SSH 能登录的 NixOS”误认为已经
声明式纳管。在线机器的真实来源、收编顺序与退役判定记录在
[inventory/README.md](./inventory/README.md)。

| 主机 | 角色 | Flake 状态 |
| --- | --- | --- |
| `conduit` | RackNerd 洛杉矶 Xray 边缘节点 | 已受管 |
| `hopper` | Oracle A1 应用与存储节点 | 已受管 |
| `repeater` | 国内阿里云中转 | 未纳管外部中转，待回收源码后收编 |
| `target` | 国内 EasyTier 与游戏端口转发节点（无 HTTP 反代或代理服务） | 已受管，计划到期退役 |
| `beacon` | Apple Silicon Mac mini，原生 macOS / nix-darwin | 根目录 `hosts/beacon` 已声明；不属于 servers Flake |

`conduit` 与国内 EasyTier 网络隔离。`hopper` 原生运行 OpenList、Navidrome、
RustFS、MySQL、PostgreSQL、MongoDB、Redis、Nginx、Xray、Komari 与 Hermes，
不安装容器运行时。

`conduit` 的实机迁移记录与可复现操作说明见
[docs/conduit-migration.md](./docs/conduit-migration.md)。
`hopper` 的 ARM64、OCI 网络、数据恢复和两阶段接管说明见
[docs/hopper-migration.md](./docs/hopper-migration.md)。

Cloudflare 边缘代理的通用代码位于独立的
`/home/dot/Projects/edge-proxy-worker` 仓库；本仓库的
[cloudflare/edge-worker](./cloudflare/edge-worker/README.md) 固定其本机 Git 提交，
只保存部署参数、SOPS 引用、Mihomo 基线和路由器适配。它独立于 NixOS 主机模块部署，
密钥只通过 Worker secret 注入。旧部署适配仍从受限 legacy checkout 归档固定提交；
隔离 canary 的当前 Flake 修订由 `edgeProxyWorker` 私有 Git SSH 非 Flake 输入锁定，
曾预接入 Target 的默认关闭模块；这些历史模块已移除，现网未启用探测服务。两地交叉
探测预览与来源边界见
[proxy-deployment](./proxy-deployment/README.md)。现网审计、灰度与清理步骤见
[docs/cloudflare-edge-migration.md](./docs/cloudflare-edge-migration.md)。

双节点代理的通用编译器、规则与 Xray 模块已拆到独立的
`/home/dot/Projects/proxy-stack` Flake，并发布在私有 GitHub 仓库。
`flake.lock` 固定其 Git 修订；远程构建端须能读取该私有仓库，发布前还须复核
访问权限与锁定源码。账户、LA/SG 真实端点、优选来源和客户端网络参数留在
[proxy-deployment](./proxy-deployment/README.md)；SOPS 密钥仍在本仓库。
隔离 canary 已登记但旧 Xray 目录仍将其关闭；现有 `clash/router-policy.json`、
`proxy-accounts.json`、旧 Worker 与订阅保持可用，新编译器尚未向现网发布。
`target` 没有加入这次双节点代理。
从**当前锁定修订**本地构建三类 Worker bundle 的命令是：

```bash
nix build path:/home/dot/.dotfiles/servers#proxyStackWorkerBundles --no-link --print-out-paths
```

此命令不解密 SOPS、不发布 Cloudflare。控制 Worker 还需要受信任的回源探测服务绑定；
配置 Worker 还需要独立的私有部署包和测试账户。完成这些验收后才能提出灰度发布。

Hopper 同时提供一个有界的官方 Nix 二进制缓存中继：它按需从
`cache.nixos.org` 下载并缓存在新加坡本地磁盘，其他受管主机优先命中该中继，
断开时自动回退到官方缓存。它不保存私有构建产物，也不构成数据备份。

## 仓库边界

`servers/` 是所有云服务器的唯一配置入口，但仍由外层 `dotfiles` Git 仓库提交与
推送。服务器本身不保存唯一配置副本：部署前从这里构建，部署后以这里的提交记录为
准。密钥只放在 `secrets/*.yaml` 的 SOPS 密文中，绝不将解密副本或运行时 `.env`
提交到 Git。

持续数据保护的架构选项、各服务的数据边界、保留策略和恢复演练见
[docs/backup-options.md](./docs/backup-options.md)。现有 `server-backups/` 中的是
迁移前加密归档，不是定时备份系统。

通过 SSH 的日常编辑与安全应用流程见
[docs/on-host-configuration.md](./docs/on-host-configuration.md)。受管机器保留一份
可 `git pull` 的本地工作副本；它不是配置的唯一来源，GitHub 的提交历史才是准绳。

## 共享安全基线

- 管理用户：`dot`
- 登录方式：仅 SSH Ed25519 公钥
- SSH 端口：`22`
- root：锁定且禁止 SSH 登录
- sudo：`dot` 免密码，便于声明式远程部署
- 防火墙：默认拒绝；共享层只开放 `22/tcp`
- 网络：`systemd-networkd`，共享启用 `BBR + fq`
- 维护：zram、fstrim、每周 Nix GC

主机服务模块可以追加自己的最小端口集合：`conduit` 额外开放 `80/tcp`、`20001/tcp` 和
`20002/tcp`、`443/tcp`；`hopper` 额外开放 `80/tcp`、`20001/tcp`、
`20002/tcp`、`443/tcp`（CDN Nginx）和 `443/udp`（Hysteria2）；
`target` 的 EasyTier 和游戏转发端口由对应主机模块单独声明。
数据库与应用端口仅监听回环地址或由防火墙隔离。

## 构建与检查

因为 `servers/` 是仓库内的独立 Flake，使用显式 `path:` 引用可在文件尚未
加入 Git 索引时也正确纳入源码：

```bash
nix flake check path:/home/dot/.dotfiles/servers
nix build \
  path:/home/dot/.dotfiles/servers#nixosConfigurations.target.config.system.build.toplevel
```

`conduit` 的镜像接管配置仍可单独构建：

```bash
nix build \
  path:/home/dot/.dotfiles/servers#nixosConfigurations.conduit.config.system.build.toplevel
```

`hopper` 是 `aarch64-linux`。x86_64 工作站只能评估配置；完整构建需要 ARM
远程构建机或 `boot.binfmt.emulatedSystems = [ "aarch64-linux" ];`。迁移时在
ARM64 kexec 安装环境中使用 `--build-on remote`，不要求工作站永久启用模拟。

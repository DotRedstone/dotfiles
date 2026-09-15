# NixOS Servers

这是独立于桌面配置的云服务器 Flake，仓库路径为
`/home/dot/.dotfiles/servers`。共享基线与每项服务都拆成单一职责模块，密钥由
SOPS 加密后随 Git 配置保存。

## 主机与纳管状态

`hosts/` 只放能够由此 Flake 重建的主机；不要把“SSH 能登录的 NixOS”误认为已经
声明式纳管。在线机器的真实来源、收编顺序与退役判定记录在
[inventory/README.md](./inventory/README.md)。

| 主机 | 角色 | Flake 状态 |
| --- | --- | --- |
| `conduit` | RackNerd 洛杉矶 Xray 边缘节点 | 已受管 |
| `hopper` | Oracle A1 应用与存储节点 | 已受管 |
| `gcp-free` | GCE `e2-micro` 代理节点 | 已有配置，等待恢复可访问地址或确认退役 |
| `repeater` | 国内服务节点 | 在线 NixOS，待回收源码后收编 |
| `target` | 国内反代与 EasyTier 节点 | 已受管 |
| `beacon` | 未确认角色 | 当前不可达，待盘点 |

`conduit` 与国内 EasyTier 网络隔离。`hopper` 原生运行 OpenList、Navidrome、
RustFS、MySQL、PostgreSQL、MongoDB、Redis、Nginx、Xray、Komari 与 Hermes，
不安装容器运行时。

`gcp-free` 的完整安装、恢复和日常维护说明见
[docs/gcp-free-migration.md](./docs/gcp-free-migration.md)。
`conduit` 的实机迁移记录与可复现操作说明见
[docs/conduit-migration.md](./docs/conduit-migration.md)。
`hopper` 的 ARM64、OCI 网络、数据恢复和两阶段接管说明见
[docs/hopper-migration.md](./docs/hopper-migration.md)。

Cloudflare 边缘代理与优选 IP 订阅代码位于
[cloudflare/edge-worker](./cloudflare/edge-worker/README.md)，它独立于 NixOS 主机
模块部署，密钥只通过 Worker secret 注入。现网审计、灰度与清理步骤见
[docs/cloudflare-edge-migration.md](./docs/cloudflare-edge-migration.md)。

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

主机服务模块可以追加自己的最小端口集合：`gcp-free` 只额外开放
`443/tcp`；`conduit` 额外开放 `80/tcp`、`20001/tcp` 和
`20002/tcp`；`hopper` 同样只额外开放 `80/tcp`、`20001/tcp` 和
`20002/tcp`，数据库与应用端口全部仅监听回环地址或由防火墙隔离。

## 构建与检查

因为 `servers/` 是仓库内的独立 Flake，使用显式 `path:` 引用可在文件尚未
加入 Git 索引时也正确纳入源码：

```bash
nix flake check path:/home/dot/.dotfiles/servers
nix build \
  path:/home/dot/.dotfiles/servers#nixosConfigurations.gcp-free.config.system.build.toplevel
```

`conduit` 的镜像接管配置仍可单独构建：

```bash
nix build \
  path:/home/dot/.dotfiles/servers#nixosConfigurations.conduit.config.system.build.toplevel
```

`hopper` 是 `aarch64-linux`。x86_64 工作站只能评估配置；完整构建需要 ARM
远程构建机或 `boot.binfmt.emulatedSystems = [ "aarch64-linux" ];`。迁移时在
ARM64 kexec 安装环境中使用 `--build-on remote`，不要求工作站永久启用模拟。

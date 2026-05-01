# 持久化存储 (Impermanence)

本系统采用 Btrfs 子卷配合 [Impermanence](https://github.com/nix-community/impermanence) 实现了“无状态根目录 (Stateless Root)”设计。

## Btrfs 子卷布局

| 子卷路径 | 挂载点 | 职责 |
| :--- | :--- | :--- |
| `@` | `/` | 根目录。每次启动时回滚至干净状态。 |
| `@home` | `/home` | 用户家目录。 |
| `@nix` | `/nix` | Nix Store。 |
| `@persist` | `/persist` | **持久化层**。存放必须保留的数据。 |
| `@log` | `/var/log` | 日志存储。作为独立子卷，**禁止**在 Impermanence 中再次持久化。 |
| `@swap` | `/swap` | 交换文件目录。 |

## 持久化原则

- **`/persist` 必须可写**: 所有的持久化路径都会链接至此，确保其分区未被挂载为只读。
- **系统身份敏感信息禁令**:
  - **严禁**持久化 `/etc/shadow`, `/etc/passwd`, `/etc/group`, `/etc/gshadow`。
  - 密码哈希统一存放在 `/persist/secrets/*.passwd` 并在 `users.nix` 中引用。
- ** neededForBoot**: 关键挂载点（如 `/persist`）在 `mounts.nix` 中必须标记为 `neededForBoot = true`。

## 维护与风险

> [!CAUTION]
> 修改 `persistence.nix` 之前务必执行 `nixos-rebuild dry-run`。
> 错误的持久化配置可能导致系统在引导阶段因为挂载失败而进入应急模式 (Emergency Mode)。

- **恢复快照**: 在回滚 `@persist` 子卷前，请确保已备份最新的密钥。
- **挂载点检查**: 修改持久化目录后，检查 `ls -la` 确认软链接指向正确。

相关链接：
- [架构概览](./architecture.md)
- [密钥管理](./secrets-sops.md)

# 持久化存储 (Impermanence)

本系统采用 Btrfs 子卷配合 [Impermanence](https://github.com/nix-community/impermanence) 实现了无状态根目录 (Stateless Root) 设计。

## Btrfs 结构

- **`/` (@)**: 根目录。每次启动时，系统会将该子卷回滚至干净快照或清空，强制保持无状态。
- **`/persist` (@persist)**: 持久化层。所有需要跨重启保存的数据都必须链接到此分区。
- **`/home` (@home)**: 用户家目录。
- **`/var/log` (@log)**: 日志存储。独立挂载，**不要**在 Impermanence 配置中重复定义持久化以避免冲突。

## 安全与禁令

- **`/persist` 状态**: 必须保持可写 (`writable`)。
- **身份文件禁止持久化**:
  - 禁止持久化 `/etc/shadow`, `/etc/passwd`, `/etc/group`, `/etc/gshadow`。
  - 密码哈希应存储在 `/persist/secrets/*.passwd` 并在 `users.nix` 中引用。

## 维护注意事项

- **快照恢复**: 恢复快照后，务必检查 `/persist` 分区的挂载状态与权限。
- **变更验证**: 修改 `persistence.nix` 前，先执行 `dry-run` 检查是否会导致系统无法引导。
- **挂载点检查**: 确保关键持久化路径（如 SSH key, GPG, 浏览器配置）在 `/persist` 下确实存在且权限正确。

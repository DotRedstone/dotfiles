# 日常维护 (Maintenance)

## 常用操作指令

| 任务 | 命令 | 别名 |
| :--- | :--- | :--- |
| **部署用户配置** | `home-manager switch --flake .#dot@warden` | `hms` |
| **部署系统配置** | `sudo nixos-rebuild switch --flake .#warden` | `nrs` |
| **验证用户配置** | `home-manager build --flake .#dot@warden` | - |
| **验证系统配置** | `sudo nixos-rebuild dry-run --flake .#warden` | - |
| **语法检查** | `nix flake check .` | - |
| **重载输入法** | `fcitx5 -r -d` | - |
| **重置桌面 Shell** | `systemctl --user restart noctalia.service` | - |

## 何时需要 Reboot？

通常情况下，NixOS 的 `switch` 操作可以实时生效，但在以下场景中需要重启系统：
1. 更新了 **内核 (Kernel)**。
2. 修改了 **引导加载程序 (Bootloader)** 配置。
3. 更新了涉及 **GPU 驱动** 或核心 **系统库 (glibc)** 的改动。
4. 修改了磁盘挂载点或 Btrfs 子卷结构。

## Git 提交规范

本仓库遵循 Conventional Commits 规范，且描述信息必须使用 **中文**。

- **格式**: `<type>(<scope>): <中文说明>`
- **常见类型**:
  - `feat`: 新功能
  - `fix`: 修复 Bug
  - `docs`: 文档更新
  - `refactor`: 重构代码
- **示例**: `fix(fcitx5): 修复 Rime 快捷键冲突`

## 回滚与风险提示

- **引导回滚**: 若系统更新后无法启动，请在引导菜单（systemd-boot）中选择旧的 Generatios。
- **Impermanence 风险**: 在修改 `persistence.nix` 之前，务必通过 `dry-run` 确认挂载点逻辑正确。若错误配置了持久化路径，可能会导致 `/persist` 目录权限混乱。

相关链接：
- [持久化存储](./impermanence.md)
- [架构概览](./architecture.md)

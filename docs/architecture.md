# 架构概览 (Architecture)

本仓库采用了高度模块化的 Nix 结构，遵循“单一职责”原则，确保系统与用户配置既能统一管理又能独立验证。

## 核心结构

| 目录/文件 | 职责 | 作用域 |
| :--- | :--- | :--- |
| `flake.nix` | 整个仓库的入口，定义 inputs 和 outputs | Flake |
| `hosts/warden/` | 主机特定配置（硬件、挂载点、内核参数） | Host |
| `modules/system/` | NixOS 系统级功能模块 | System |
| `modules/system/desktop/` | 原子化的桌面环境组件 (Niri, SDDM, Graphics, etc.) | System |
| `modules/system/users/` | 原子化的用户账户、Shell 及核心工具链配置 | System |
| `modules/system/persistence/` | 原子化的持久化路径配置 (System, User, Apps, etc.) | System |
| `home/dot/` | Home Manager 用户环境与应用配置 | Home Manager |
| `scripts/` | 手动诊断脚本与维护助手 | Script |

## 模块边界与原则

- **Host vs System**: `hosts/` 目录仅存放与物理硬件强相关的配置。通用的系统逻辑（如 Docker, I18N）应封装在 `modules/system/` 中。
- **System vs Home**: 系统级配置（如引导、文件系统、全局服务）位于 `modules/system/`；用户级配置（如桌面环境、编辑器、个人应用）位于 `home/dot/`。
- **禁止全局污染**: 禁止将特定应用的 workaround（如特定环境变量或补丁）写进全局系统配置。应将其保留在应用所在的 Home Manager 模块中。

## 验证流程

- **Home Manager 改动**: 运行 `home-manager build --flake .#dot@warden`。
- **NixOS 系统改动**: 运行 `sudo nixos-rebuild dry-run --flake .#warden`。
- **全局验证**: 运行 `nix flake check .`。

相关链接：
- [日常维护](./maintenance.md)
- [持久化存储](./impermanence.md)

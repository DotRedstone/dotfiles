# 架构概览 (Architecture)

本仓库采用两套独立 Flake：根目录管理 `warden` 桌面与 `dot@warden` 用户环境，
`servers/` 管理云服务器。二者共用 Git 历史和文档规范，但绝不混用构建、部署或
密钥边界。完整改动路由见 [仓库导航与改动路由](./repository-map.md)。

## 核心结构

| 目录/文件 | 职责 | 作用域 |
| :--- | :--- | :--- |
| `flake.nix` | 整个仓库的入口，定义 inputs 和 outputs | Flake |
| `hosts/warden/` | 主机特定配置（硬件、挂载点、内核参数） | Host |
| `modules/system/` | NixOS 系统级功能模块 | System |
| `modules/system/desktop/` | 原子化的桌面环境组件 (Niri, SDDM, Graphics, etc.) | System |
| `modules/system/users/` | 原子化的用户账户、Shell 及核心工具链配置 | System |
| `modules/system/persistence/` | 原子化的持久化路径配置 (System, User, Apps, etc.) | System |
| `modules/system/boot/` | 原子化的引导加载程序、内核及回滚逻辑配置 | System |
| `modules/system/virtualization/` | 原子化的虚拟化配置 (Docker, Libvirt, Tools) | System |
| `modules/system/hardware/` | 原子化的硬件服务 (Audio, Bluetooth, Power, Tools) | System |
| `modules/system/nix/` | 原子化的 Nix 包管理器、GC 及 nixpkgs 配置 | System |
| `modules/system/network/` | 原子化的网络管理、代理及防火墙配置 | System |
| `home/dot/` | Home Manager 用户环境与应用配置 | Home Manager |
| `scripts/` | 手动诊断脚本与维护助手 | Script |
| `servers/flake.nix` | 云服务器独立 Flake 的入口 | Server Flake |
| `servers/hosts/` | 每台受管服务器的组装、平台事实与服务实例化 | Server Host |
| `servers/modules/server/` | 服务器共享安全与网络基线 | Server System |
| `servers/modules/services/` | 可复用服务的 option 模块 | Server Service |
| `servers/cloudflare/` | Worker、边缘入口与优选 IP 控制面 | Edge |

## 模块边界与原则

- **Host vs System**: `hosts/` 目录仅存放与物理硬件强相关的配置。通用的系统逻辑（如 Docker, I18N）应封装在 `modules/system/` 中。
- **System vs Home**: 系统级配置（如引导、文件系统、全局服务）位于 `modules/system/`；用户级配置（如桌面环境、编辑器、个人应用）位于 `home/dot/`。
- **Desktop vs Servers**: 根 `flake.nix` 只能构建 `warden` 与 `dot@warden`；云服务器必须从 `servers/flake.nix` 以 `path:./servers` 调用。
- **Host vs Service (Servers)**: `servers/hosts/<name>/` 只组装该机器；可复用服务逻辑放在 `servers/modules/services/`，不复制粘贴。
- **禁止全局污染**: 禁止将特定应用的 workaround（如特定环境变量或补丁）写进全局系统配置。应将其保留在应用所在的 Home Manager 模块中。

## 验证流程

- **Home Manager 改动**: 运行 `home-manager build --flake .#dot@warden`。
- **NixOS 系统改动**: 运行 `sudo nixos-rebuild dry-run --flake .#warden`。
- **全局验证**: 运行 `nix flake check .`。
- **服务器改动**: 运行 `nix flake check path:./servers`；再按架构选择受管主机构建。

相关链接：
- [日常维护](./maintenance.md)
- [持久化存储](./impermanence.md)
- [仓库导航与改动路由](./repository-map.md)
- [服务器 Flake](../servers/README.md)

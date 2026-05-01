# 架构概览 (Architecture)

本仓库采用了高度模块化的 Nix 结构，遵循“单一职责”原则，确保系统与用户配置既能统一管理又能独立验证。

## 目录结构与职责

- **`flake.nix`**: 整个仓库的入口，定义了输入 (inputs) 和输出 (outputs)，包括 NixOS 实例和 Home Manager 实例。
- **`hosts/warden/`**: 特定主机的硬件配置文件。
  - 包含硬件扫描 (`hardware-configuration.nix`)、挂载点 (`mounts.nix`) 以及主机名、内核参数等身份定义。
- **`modules/system/`**: NixOS 系统级模块。
  - 负责引导 (boot)、用户账户 (users)、字体 (fonts)、网络 (network) 以及全局持久化策略 (persistence)。
- **`home/dot/`**: Home Manager 用户级模块。
  - 负责具体应用的配置、桌面环境设置以及用户环境变量。
  - 核心子模块包括：
    - `fcitx5/`: 输入法环境与主题。
    - `noctalia/`: 桌面 Shell 与视觉同步逻辑。
    - `wechat/`: 微信客户端及其通知桥接。
    - `niri/`: 窗口管理器设置。

## 配置验证规则

- **Home Manager 改动**: 运行 `home-manager build --flake .#dot@warden` 验证。
- **System 改动**: 运行 `sudo nixos-rebuild dry-run --flake .#warden` 验证。
- **模块边界**:
  - 禁止将特定应用的 workaround 写进全局系统配置。
  - 保持模块独立性，减少跨目录的隐式依赖。

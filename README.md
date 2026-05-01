# Dotfiles of Dot

这是用户 `dot` 的个人 NixOS 系统和 Home Manager 配置文件。

## 核心架构

- **主机 (Host)**: `warden` (Redmi Book Pro 16 2024)
- **用户 (User)**: `dot`
- **桌面环境**: [Niri](./docs/desktop-niri.md) + [Noctalia](./docs/noctalia.md)
- **输入法**: [Fcitx5 + Rime Ice + Noctalia 动态主题](./docs/fcitx5-rime.md)
- **存储方案**: [Btrfs + Impermanence](./docs/impermanence.md) (无状态根目录)
- **通知系统**: [QQ 原生通知，WeChat 使用自定义通知桥](./docs/notifications.md)

## 常用命令

| 命令 | 说明 |
| :--- | :--- |
| `hms` | 更新 Home Manager 用户配置 (`home-manager switch`) |
| `nrs` | 更新 NixOS 系统配置 (`sudo nixos-rebuild switch`) |
| `nix flake check .` | 验证 Flake 语法与结构 |

## 文档指引

- [AGENTS.md](./AGENTS.md): 针对 AI 协作助手的技术规范指南。
- [docs/](./docs/): 详细的功能模块文档：
  - [架构概览](./docs/architecture.md)
  - [日常维护](./docs/maintenance.md)
  - [Niri 桌面配置](./docs/desktop-niri.md)
  - [Noctalia 视觉系统](./docs/noctalia.md)
  - [输入法配置](./docs/fcitx5-rime.md)
  - [持久化存储](./docs/impermanence.md)
  - [密钥管理](./docs/secrets-sops.md)
  - [微信集成](./docs/wechat.md)
  - [通知链路](./docs/notifications.md)
  - [终端 (WezTerm)](./docs/terminal-wezterm.md)
  - [编辑器 (NixVim)](./docs/editor-nixvim.md)
  - [应用列表](./docs/apps.md)

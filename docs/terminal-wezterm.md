# 终端 (WezTerm)

WezTerm 是系统的默认终端，使用 GPU 渲染，并通过 Lua 模块维护终端行为与外观。

## 核心特性

- **渲染后端**: 强制启用 `WebGpu` 模式，并设为 `HighPerformance`。
- **Wayland 支持**: 原生支持 Wayland 协议。
- **动画帧率**: `animation_fps` 设置为 `165`，与此主机的高刷新率显示器配合使用。
- **字体栈**:
  1. `Maple Mono NF`
  2. `Noto Sans CJK SC` (中文回退)
  3. `Symbols Nerd Font Mono`

## 远程域 (SSH Domains)

WezTerm 预集成了以下常用 VPS 节点，可通过快捷键或命令面板快速连接：

| 节点名称 | 别名 | 描述 |
| :--- | :--- | :--- |
| Beacon (Mac mini) | `beacon` | 本地 macOS / nix-darwin 无头主机 |
| Conduit (RN) | `conduit` | 节点服务器 |
| Hopper (Oracle) | `hopper` | 备份/Oracle 节点 |
| Target (Tencent) | `target` | 腾讯云远程构建 |
| Repeater (Aliyun) | `repeater` | 未纳管外部节点，承担中转并运行 Vaultwarden、Komari、AstrBot 等服务；保留 SSH 别名，不登记登录凭据，仅有 Hopper 备份拉取所用的 restic/SSH 凭据 |

## 核心快捷键

| 按键组合 | 功能 |
| :--- | :--- |
| `Ctrl + Shift + S` | 调出 WezTerm 启动器 (Launcher) |
| `Ctrl + Shift + P` | 调出命令面板 |
| `Ctrl + Shift + N` | 开启新窗口 |
| `Ctrl + Shift + W` | 关闭当前标签页 |

## 维护原则

- **Live Reload**: `wezterm.lua` 使用了 `mkOutOfStoreSymlink` 链接，修改 `.dotfiles` 中的配置文件后**无需**运行 `hms` 即可实时生效。
- **配色同步**: 配色方案名为 `Noctalia`，其色彩 Token 随壁纸动态同步。

相关链接：
- [Noctalia 视觉系统](./noctalia.md)
- [密钥管理](./secrets-sops.md)

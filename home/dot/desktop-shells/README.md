# 桌面 Shell 模块与切换器

本目录打包并维护 **DMS 2 (`dux-shell`)** 与 **Clavis Shell (`StatIndet/quickshell`)**，并提供两者之间的实时切换。当前默认桌面外壳为 **DMS 2**。

| 范畴 | 位置 |
| --- | --- |
| 模块入口 | `default.nix` |
| DMS 2 (Dux Shell) 打包与默认服务 | `dms.nix` |
| DMS 深浅色向 Antigravity、VS Code 系编辑器的同步 | `dms-color-scheme.nix` |
| Clavis Shell、`key-cli`、`qt6-m3shapes` 打包与按需服务 | `clavis.nix` |
| 运行时外壳切换命令 (`desktop-shell`) | `switcher.nix` |

## 隔离与安全边界

- 登录会话通过 `Install.WantedBy` 默认启动 `dms.service`。`clavis-shell.service` 为按需服务，避免多个外壳同时抢占通知服务（`org.freedesktop.Notifications`）或顶栏区域。
- `noctalia.service` 已退出切换器管理范围，仅作为独立按需服务保留；其视觉系统（颜色令牌与用户模板）仍被各应用主题引用。
- 切换命令 `desktop-shell` 会先停止其余外壳服务并清理残留 `quickshell` 进程，随后启动目标外壳并同步系统托盘（`StatusNotifierItem`）。

## 切换与验证

构建与生效：

```bash
home-manager switch --flake path:.#dot@warden
```

运行时切换：

```bash
desktop-shell status    # 查看当前激活的外壳服务
desktop-shell dms       # 切换到 DMS 2 (Dux Shell)
desktop-shell clavis    # 切换到 Clavis Shell (StatIndet/quickshell)
```

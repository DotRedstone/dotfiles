# Home Manager：dot 的用户环境

`home/dot/default.nix` 是唯一的用户级 switchboard。每个一级目录或模块负责一个
可独立理解的应用、终端能力或桌面集成；新行为应进入所属模块，不要追加到
`default.nix` 的 `home.packages`。

## 阅读入口

| 要修改的内容 | 入口 |
| --- | --- |
| 桌面会话、窗口、快捷键 | `niri/` |
| Noctalia Shell、插件、翻译与动态主题 | [`noctalia/README.md`](./noctalia/README.md) |
| 输入法和 Rime | [`fcitx5/README.md`](./fcitx5/README.md) |
| Neovim / NixVim | [`nixvim/README.md`](./nixvim/README.md) |
| 浏览器 | `firefox/`、`chrome/`、`zen-browser/` |
| 终端与交互 Shell | `fish/`、`starship/`、`wezterm/`、`zellij/` |
| 开发工具 | `dev/`、`vscode/`、`nixvim/`、`cli-tools/` |
| 应用默认打开方式 | `default-apps/` |
| SOPS 解密后的用户密钥映射 | `secrets/` |

## 改动规则

- 所有 `.nix` 模块保留标准头部；`default.nix` 只作为 switchboard。
- 应用专属环境变量、桌面条目、补丁和启动包装留在该应用目录，不能借用全局模块“顺手修复”。
- Noctalia 生成的状态、浏览器 profile、插件 materialization 和密钥解密文件都属于运行时数据，不提交。
- 修改本树后运行：

  ```bash
  home-manager build --flake .#dot@warden
  ```

只有在用户明确要应用变更时再使用 `home-manager switch` 或 `hms`。

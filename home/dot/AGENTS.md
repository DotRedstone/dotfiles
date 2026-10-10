# Home Manager Agent Guide

本目录管理用户 `dot` 的 Home Manager 配置。根目录 `AGENTS.md` 的全部规则仍然
有效；本文件只补充用户层的路由和边界。

## 先读哪里

1. `default.nix`：确认功能是否已存在对应模块。
2. 目标模块的 `default.nix`：只将它作为 import switchboard。
3. 目标目录的 `README.md`（若存在）：遵循目录专属边界。
4. 对桌面 / 输入法 / 主题问题，再阅读根目录 `docs/` 的相关文档。

## 用户层边界

- 不将需要 root、systemd system service、内核、挂载或硬件的配置放进本目录。
- 不将单个应用的兼容性 workaround 放进 `niri/`、`theme/` 或全局 session variables。
- 不读取、打印、提交 `secrets/` 解密结果、浏览器令牌、聊天数据库或运行时缓存。
- 变更一个应用时，只验证该 Home Manager 输出；除非改动跨越系统边界，不要顺带执行 NixOS switch。

## 特殊目录

- `fcitx5/`：Rime 补丁按职责拆分；XWayland-safe 输入法主题保持矩形、不透明回退。
- `noctalia/`：优先使用 MD3 token；不要提交 app-managed state 或生成缓存。
- `zen-browser/`：性能、profile 和扩展的修复必须先做可逆 A/B 验证，不能凭感觉调整全局电源策略。
- `nixvim/`：插件组放在 `nixvim/plugins/`；不要恢复已清理的单体 `plugins.nix`。

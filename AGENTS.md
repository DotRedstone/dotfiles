# Dotfiles Agent 协作指南

## 仓库用途

本仓库管理 `warden` 主机与 `dot` 用户的 NixOS、Home Manager 个人配置。面向使用者的入口见 [README.md](./README.md)。

`servers/` 是独立的 NixOS 服务器 Flake。选择命令前先阅读 [docs/repository-map.md](./docs/repository-map.md)：桌面与服务器共享 Git 历史，但部署目标不同。

基本原则：

- 改动应可回退，模块应小而职责单一。
- 不为修复单个应用而损害整个桌面环境；优先采用应用局部的处理方式。
- 保持 Noctalia 视觉系统一致。

## 配置与独立项目的边界

- 本仓库以声明式配置、主机专属值、密钥引用和使用工具所需的最少集成为主。
- 功能成长时重新评估边界。可复用实现具备明确接口、独立测试或发布周期，或者已能在本配置之外使用时，应及时把实现及其维护文档迁移至 `/home/dot/Projects/` 下的独立 Git 仓库。本仓库只保留固定版本的引用、模块实例化及部署专属配置。
- 不因一个小型 Nix 模块、模板或主机专属辅助脚本跨越几个文件，就将其拆为独立项目。是否拆分取决于实际的独立维护需要。
- 迁移应明确范围：记录接口与维护归属，保留可用的回退路径，分别验证独立项目与受影响的 Flake。锁定依赖版本不能证明实际部署已生效。
- 迁移前，将通用行为与本部署的账号、联系人标识、真实端点、域名、令牌和主机选择分开。不得把这些值复制到新项目的源码、README、示例、样例数据、测试或 Git 历史。示例使用合成数据；真实值按需保留在本仓库配置或 SOPS 中。

## 常用命令

```bash
home-manager build --flake .#dot@warden
home-manager switch --flake .#dot@warden
sudo nixos-rebuild dry-run --flake .#warden
sudo nixos-rebuild switch --flake .#warden
nix flake check .
nix flake check path:./servers
```

验证规则：

- Home Manager 改动使用 `home-manager build` 或 `home-manager switch` 验证。
- 系统模块改动使用 `nixos-rebuild dry-run` 或 `nixos-rebuild switch` 验证。
- 仅修改 Home Manager 时，不运行 `sudo nixos-rebuild switch`。
- 只验证一侧时，不声称整个配置已通过验证。
- 服务器改动使用 `servers/flake.nix`，遵循 `servers/AGENTS.md`；不得误将桌面的 `nixos-rebuild` 命令用于远程服务器。

## 修改前的阅读路径

编辑前先阅读最近的入口模块及所在目录的 README（如有）。

| 改动范围 | 先阅读 | 修改边界 |
| --- | --- | --- |
| Warden 硬件、挂载、主机身份 | `hosts/warden/default.nix` | `hosts/warden/` |
| Warden 全局系统行为 | `modules/system/default.nix` | 一个 `modules/system/<domain>/` 模块 |
| 用户应用或桌面行为 | `home/dot/default.nix` | 一个 `home/dot/<app>/` 模块 |
| 服务器 | `servers/README.md`、`servers/AGENTS.md` | `servers/hosts/` 或 `servers/modules/` |
| Cloudflare Worker | `servers/cloudflare/README.md` | `servers/cloudflare/edge-worker/` |

入口文件不承载具体功能。`default.nix` 用于组织模块；新行为应放入职责单一的同级模块，并显式引入。

## 工作区与 Git

- 先运行 `git status --short`；已有的未提交改动属于用户。
- 不格式化、移动、暂存、撤销或提交无关改动。
- 纯文档、纯重构和行为改动分别提交。
- 新 Nix 文件在被 Flake 引用但尚未暂存时，可使用 `git add -N`，或通过 `path:.` 验证，使求值过程能看到该文件。

## 文档约定

- 根目录 `README.md` 是使用者入口；`docs/` 说明跨模块概念。
- 复杂目录使用简洁的 `README.md` 说明职责、入口、安全边界和验证方式，不写入凭据或运行时数据。
- `AGENTS.md` 记录执行约束，不包含令牌、私钥、个人数据、订阅地址或解密后的 SOPS 值。
- 结构变化使 README 或导航表失效时，在同一变更中更新它们。
- 面向维护者的文档和新写的解释性注释以简洁中文为主；命令、路径、选项、代码标识符和上游术语保持准确。README、其他文档与模块注释对同一组件使用一致的名称。
- README、指南、代码注释和发布说明使用中立、准确的书面语。不直接复制用户或 Agent 的口语化表述；明确写出行为及原因。
- 每项事实只保留一处主要说明，其他位置通过链接引用。在文档与报告中区分预期设计、声明式源码、构建结果和实际运行状态；不将临时日志或单次任务 TODO 写入长期架构文档。
- 说明边界存在的原因、验证方法及高风险改动的恢复方式。简单改动保持简单；只有多步骤工作需要交接或审查时才增加 TODO 或设计文档。
- 修改相关文档时应用这些规则，不为统一风格而批量改写无关文档。

## Nix 模块文件头

所有 `.nix` 模块以以下格式开头：

```nix
# ---
# Module: <易于识别的模块名称>
# Description: <概括单一职责的一句话>
# Scope: <System | Home Manager | Host | Theme | Script | Flake>
# ---
```

可选说明：

```nix
# Notes:
# - <维护警示>
# - <不应在此修改的事项>
```

规则：

- `Description` 只描述一项职责，避免使用“配置”等含糊描述。
- `default.nix` 的 `Module` 字段应使用 `Entry` 或 `Switchboard`。
- 高风险模块应填写 `Notes`。
- 仅在较长模块需要导航时使用简短的 `# [Section]` 注释；沿用附近的名称与语言习惯，不为每个选项增加标签。
- 在相关代码旁解释不明显的选择、不变量、安全边界和回退约束。不复述选项已有的含义，也不把任务对话写入注释。

## 仓库目录边界

- `flake.nix`：Flake 入口。
- `hosts/warden/`：主机专属硬件、挂载、身份和交换空间。
- `modules/system/`：NixOS 系统模块。
- `home/dot/`：Home Manager 用户模块。
- `home/dot/fcitx5/`：Fcitx5、Rime 及输入法主题集成。
- `home/dot/noctalia/`：Noctalia Shell 配置与用户模板。
- `home/dot/wechat/`：微信软件包与通知桥接。
- `scripts/`：手动诊断与辅助脚本。

一次行为改动应落在一个负责该行为的模块中；不在全局桌面配置中加入应用专属变通方案；不混合重构与行为改动。

## Fcitx5 与 Rime

- Fcitx5 和 Rime 配置按职责拆分；Rime 补丁位于 `home/dot/fcitx5/rime/patches/`。
- 候选词按键只修改 `keybindings.nix`；CapsLock / Shift 行为只修改 `ascii-composer.nix`。
- Lua 处理器只修改 Rime Lua 模块或 `lua-processors.nix`；主题只修改 `theme.nix`、自定义主题或 Noctalia 模板。
- 微信 UOS 使用 XWayland / fcitx4 兼容路径，透明圆角候选框背景可能显示黑角。Inflex 同步主题提供适用于 XWayland 的矩形回退；不要在该类主题中重新加入透明圆角。

## Noctalia 主题

- Noctalia 用户模板用于动态调色板同步；优先使用 Noctalia 颜色令牌，避免写死十六进制颜色。
- 使用 MD3 语义令牌：`surface`、`on_surface`、`surface_variant` / `outline`、`primary`、`on_primary`。
- 不提交生成的缓存文件。Noctalia 需要在 `~/.local/share/fcitx5/themes` 下生成主题时，不要再次将该目录做成只读的 `symlinkJoin`。

## 持久化与 Impermanence

高风险约束：

- 不持久化 `/etc/shadow`、`/etc/passwd`、`/etc/group` 或 `/etc/gshadow`。
- 密码哈希应保存在 `/persist/secrets/*.passwd`。
- 不随意修改 Btrfs 子卷挂载选项；`/persist` 必须保持可写。
- 已作为子卷挂载的路径避免重复声明持久化。

## 微信

- 微信通知桥接较脆弱且涉及敏感数据；不输出 SQLCipher 密钥、不提交运行时密钥缓存、不读取或暴露私人消息数据库内容。
- 不通过降低全局透明度或破坏全局主题来修复微信。

## QQ

- Linux QQ 已原生发送 `org.freedesktop.Notifications.Notify` 通知。除非明确要求，不构建 QQ 数据库桥接；优先诊断原生通知和 portal。

## 提交格式

使用 Conventional Commits：

```text
feat(scope): ...
fix(scope): ...
refactor(scope): ...
style(scope): ...
docs(scope): ...
chore(scope): ...
```

推荐作用域：`fcitx5`、`rime`、`noctalia`、`wechat`、`qq`、`persistence`、`i18n`、`niri`、`theme`、`system`、`home`、`repo`。

- 一个提交只包含一种改动类型，不混合重构与行为改动。
- 提交前说明验证命令及结果。
- **提交描述必须使用中文**，类型和作用域保持英文，例如 `fix(wechat):`。

示例：

```text
refactor(fcitx5): 原子化 Rime 配置
fix(wechat): 缓存所有 SQLCipher 密钥候选
docs(repo): 添加 Agent 协作规范
```

## 安全约束

- 除非有意更新依赖，否则不修改锁文件。
- 不提交密钥、令牌、私钥或生成的运行时缓存。
- 不通过仓库代码修改 `/persist` 下的用户持久数据。
- 不因用户定制看起来特殊就将其移除。
- 破坏性改动先询问；安全诊断不需要确认。

## 任务报告

每次任务结束时报告修改的文件、行为是否变化、验证命令及结果、风险与回退方式，以及用户是否仍需运行 Home Manager、NixOS rebuild、重启系统或重启服务。

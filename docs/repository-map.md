# 仓库导航与改动路由

本仓库同时保存一台桌面主机和多台云服务器的 NixOS 配置。两者在同一 Git
历史中协作，但属于 **两个独立 Flake**：不要把其中一方的构建或部署命令用于另一方。

## 先判断改动落点

| 需求 | 首先阅读 | 主要改动位置 | 最小验证 |
| --- | --- | --- | --- |
| Warden 硬件、挂载、休眠或主机身份 | `hosts/warden/default.nix` | `hosts/warden/` | `sudo nixos-rebuild dry-run --flake .#warden` |
| Warden 全局系统能力 | `modules/system/default.nix` | `modules/system/<domain>/` | `sudo nixos-rebuild dry-run --flake .#warden` |
| 桌面、Shell、应用和用户服务 | `home/dot/default.nix` | `home/dot/<app>/` | `home-manager build --flake .#dot@warden` |
| Niri / Noctalia / 视觉语言 | `docs/desktop-niri.md`、`home/dot/noctalia/README.md` | 对应 Home Manager 模块 | `home-manager build --flake .#dot@warden` |
| Fcitx5 / Rime | `docs/fcitx5-rime.md`、`home/dot/fcitx5/README.md` | `home/dot/fcitx5/` | `home-manager build --flake .#dot@warden` |
| 云主机或服务器服务 | `servers/README.md`、`servers/AGENTS.md` | `servers/hosts/` 或 `servers/modules/` | `nix flake check path:./servers` |
| Cloudflare Worker / 优选 IP | `servers/cloudflare/README.md` | `servers/cloudflare/edge-worker/` | 该目录的 `npm run check` |
| 密钥、SOPS 或持久化 | `docs/secrets-sops.md`、`docs/impermanence.md` | 对应声明模块 | 只做安全的构建或 dry-run |

## 两个 Flake 的边界

```text
.
├── flake.nix                 Warden 桌面 Flake（x86_64-linux）
├── hosts/warden/             此电脑不可复用的硬件和身份
├── modules/system/           Warden 可复用的系统能力
├── home/dot/                 dot 的 Home Manager 模块
└── servers/
    ├── flake.nix             云服务器 Flake
    ├── hosts/                每台已受管主机的组装层
    ├── modules/server/       所有服务器共享安全基线
    ├── modules/services/     可复用的服务选项模块
    └── cloudflare/           Worker 与边缘控制面
```

桌面 Flake 的唯一输出是 `warden` 和 `dot@warden`；服务器主机则以
`servers#hopper`、`servers#conduit` 等名称输出。服务器清单中“可 SSH”不等于
“已声明式受管”，当前收编状态以 `servers/inventory/README.md` 为准。

## Agent 的最短工作流

1. 先读根目录 `AGENTS.md`，再读当前目录及父目录中更具体的 `AGENTS.md`。
2. 先运行 `git status --short`；将已有脏改动视为用户工作，不重排、不格式化、不纳入提交。
3. 从本页的表格定位 switchboard，再追到单职责模块；不要直接把新逻辑堆回入口文件。
4. 文档改动与行为改动分成独立提交。涉及密钥、远程部署、网络入口或数据迁移时，先说明风险与回滚边界。
5. 用与作用域匹配的命令验证，最后更新相关 README / 架构文档，说明行为、验证和回滚方式。

## 文档维护约定

- 根目录 `README.md` 是给人快速找到入口的索引。
- `docs/` 存放跨模块的概念、维护和故障处理说明。
- 复杂目录自己的 `README.md` 只记录该目录的职责、入口、文件分工和安全边界，避免复制整份全局文档。
- `AGENTS.md` 记录执行约束；它不保存凭据、主机 IP、订阅 URL、解密后的 SOPS 内容或临时排障输出。

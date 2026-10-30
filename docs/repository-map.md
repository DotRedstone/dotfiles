# 仓库导航与改动路由

本仓库同时保存一台桌面主机和多台云服务器的 NixOS 配置。两者在同一 Git
历史中协作，但属于 **两个独立 Flake**：不要把其中一方的构建或部署命令用于另一方。
双节点代理的通用实现另在 `/home/dot/Projects/proxy-stack` 独立 Git/Flake 仓库；
`servers/flake.nix` 通过锁定的 `proxyStack` input 引用它，Warden Flake 不引用。

## 先判断改动落点

| 需求 | 首先阅读 | 主要改动位置 | 最小验证 |
| --- | --- | --- | --- |
| Warden 硬件、挂载、休眠或主机身份 | `hosts/warden/default.nix` | `hosts/warden/` | `sudo nixos-rebuild dry-run --flake .#warden` |
| Warden 全局系统能力 | `modules/system/default.nix` | `modules/system/<domain>/` | `sudo nixos-rebuild dry-run --flake .#warden` |
| Beacon（Mac mini 无头主机） | `hosts/beacon/README.md` | `hosts/beacon/` | `nix eval --raw .#darwinConfigurations.beacon.system.drvPath` |
| 桌面、Shell、应用和用户服务 | `home/dot/default.nix` | `home/dot/<app>/` | `home-manager build --flake .#dot@warden` |
| Niri / Noctalia / 视觉语言 | `docs/desktop-niri.md`、`home/dot/noctalia/README.md` | 对应 Home Manager 模块 | `home-manager build --flake .#dot@warden` |
| Fcitx5 / Rime | `docs/fcitx5-rime.md`、`home/dot/fcitx5/README.md` | `home/dot/fcitx5/` | `home-manager build --flake .#dot@warden` |
| 云主机或服务器服务 | `servers/README.md`、`servers/AGENTS.md` | `servers/hosts/` 或 `servers/modules/` | `nix flake check path:./servers` |
| 双节点代理通用规则或编译器 | `/home/dot/Projects/proxy-stack/README.md` | 独立 `proxy-stack` 仓库 | `node --test test/*.test.mjs`、`nix flake check path:.` |
| Cloudflare 入口 IP 本地测速工具 | `/home/dot/Projects/cf-optimizer/README.md` | 独立 `cf-optimizer` 仓库 | 以该项目 README 和实际实现为准 |
| Worker 协议、优选池与配置生成器 | `/home/dot/Projects/edge-proxy-worker/README.md` | 独立 `edge-proxy-worker` 仓库 | `npm run check` |
| 代理账户、节点与来源 | `servers/proxy-deployment/README.md` | `servers/proxy-deployment/` 与 SOPS | 锁定版本编译器 `validate` 和两节点求值 |
| Cloudflare Worker 部署参数与路由器适配 | `servers/cloudflare/README.md` | `servers/cloudflare/edge-worker/` | `node scripts/deploy.mjs --dry-run` |
| 密钥、SOPS 或持久化 | `docs/secrets-sops.md`、`docs/impermanence.md` | 对应声明模块 | 只做安全的构建或 dry-run |

## 两个 Flake 的边界

```text
.
├── flake.nix                 Warden 桌面 Flake（x86_64-linux）
├── hosts/warden/             此电脑不可复用的硬件和身份
├── hosts/beacon/             Mac mini 的 nix-darwin 主机配置（aarch64-darwin）
├── modules/system/           Warden 可复用的系统能力
├── home/dot/                 dot 的 Home Manager 模块
└── servers/
    ├── flake.nix             云服务器 Flake
    ├── hosts/                每台已受管主机的组装层
    ├── modules/server/       所有服务器共享安全基线
    ├── modules/services/     可复用的服务选项模块
    └── cloudflare/           Worker 与边缘控制面
```

桌面 Flake 输出 `warden`、`dot@warden`，以及在 Mac mini 上部署的
`darwinConfigurations.beacon`；服务器主机则以
`servers#hopper`、`servers#conduit` 等名称输出。服务器清单中“可 SSH”不等于
“已声明式受管”，当前收编状态以 `servers/inventory/README.md` 为准。
`proxy-stack` 只保存通用代码，并作为 `servers/` 的私有远端锁定 input。
账户、真实节点、SOPS 和优选来源仍由 `servers/` 管理；接入 input 不等于现网发布。

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

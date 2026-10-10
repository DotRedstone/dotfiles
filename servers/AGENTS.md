# Servers Agent Guide

`servers/` 是独立的云服务器 Flake，不继承根 Flake 的构建目标。根目录
`AGENTS.md` 的安全、密钥和提交规则仍然有效，本文件定义服务器层的额外约束。

## 阅读顺序

1. `README.md`：主机角色、共享基线和构建限制。
2. `inventory/README.md`：确认主机是否真的已受管。
3. `hosts/<name>/default.nix`：只负责该主机的组装、身份和 SOPS 入口。
4. `modules/server/`：所有主机共享的安全与网络基线。
5. `modules/services/`：服务的可复用选项定义。
6. `hosts/<name>/<domain>/`：主机对服务的最小化实例化。

## 安全与部署

- 任何远程变更先说明影响面、现有 SSH 保活策略、回滚路径和是否会改变公网入口。
- `hosts/` 只放可从本 Flake 重建的主机；仅能 SSH 登录的机器先记录在 `inventory/`。
- 密钥只通过 SOPS 声明路径使用。不要提交 `.env`、私钥、订阅 token、Cloudflare 凭据、解密 YAML 或 Restic 密码。
- 不将应用数据目录、数据库数据或对象存储内容写进 Nix store，也不要把 Docker 当作默认逃生方案。
- 网络、Xray、Cloudflare、备份和身份系统的改动应保持现有连接的可回退路径，不得把“构建成功”称为线上验证。

## 验证与部署命令

```bash
nix flake check path:/home/dot/.dotfiles/servers
nix build path:/home/dot/.dotfiles/servers#nixosConfigurations.<host>.config.system.build.toplevel
```

Hopper 是 `aarch64-linux`；在 x86_64 工作站上优先评估，完整构建使用远程 ARM
构建机。部署前优先 `nixos-rebuild test`；确认服务、监听端口和 SSH 会话均正常后，
才允许 `switch`。不把未验证的运行时状态写回声明配置。

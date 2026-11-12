# 云电脑 box 的 Home Manager

本目录管理平台维护的 Debian 云电脑上 `box` 用户的 Home Manager 环境，仅涉及用户层，不负责 root、内核或系统服务。云电脑重置后，已安装的软件可能被清空。

## 模块与入口

- `default.nix`：`box@cloud` 的入口，声明用户身份并组织模块。
- `nix.nix`：写入用户级 `~/.config/nix/nix.conf`，启用 `nix-command` 和 `flakes`。
- `network.nix`：仅安装 `mihomo`，不声明节点或启动服务。

`nix.nix` 直接写 `nix.conf` 而不使用 `nix.settings`，因为后者要求 Home Manager 指定 `nix.package`，可能切换用户 profile 中已安装的 Nix 版本。

## 安全边界

节点、订阅和密钥不进入仓库，后续通过 SOPS 引用。平台镜像已有的 `git`、`node`、`gh` 等工具不重复安装。

## 验证与恢复

在云电脑上，从仓库根目录运行：

```bash
home-manager build --flake .#box@cloud
```

确认构建成功后，可按需执行 `home-manager switch --flake .#box@cloud`。需要回滚时，使用 `home-manager generations` 查看历史代并切回上一代。云电脑重置会清空已安装软件，恢复运行环境后重新执行 Home Manager switch 即可。

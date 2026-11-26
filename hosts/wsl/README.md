# WSL 主机（`wsl`）

本目录是 `nixosConfigurations.wsl` 的组装层：NixOS-WSL 系统模块，以及一份 **仅用于 WSL** 的 Home Manager 环境。默认用户为 `nixos`，`networking.hostName` 为 `nixos-wsl`。flake 属性名仍是 `wsl`，日常更新使用 `nh os switch -H wsl`（`-H` 对应属性名，不是 hostName）。

日常更新在 WSL 内进行，仓库位于 `/home/nixos/.dotfiles`（由用户名拼出，即 `/home/${username}/.dotfiles`）：

```bash
nh os switch ~/.dotfiles -H wsl
# 或使用缩写 nrs
```

`programs.nh.flake` 与 fish `NH_FLAKE` 均为 `/home/${username}/.dotfiles`（默认即 `/home/nixos/.dotfiles`）。这里的 `nrs` / `nrb` 只存在于 `hosts/wsl/home/shell/fish.nix`，不会改动 warden 在 `home/dot/fish/config.nix` 中的缩写。

## 入口

| 内容 | 路径 |
| :--- | :--- |
| 身份与可选开关 | `profile.nix` |
| 主机装配 | `default.nix` |
| 系统模块 | `system/` |
| Home Manager | `home/`（不要引入 `home/dot/default.nix`） |

Home 中的 `claude-code` 复用 `home/dot/claude-code`；其余 CLI harness、轻量 neovim、自包含 starship/zellij 以及 rust 工具链是本目录的专用模块。

## 构建镜像

在已启用 Flakes 的 `x86_64-linux` 机器上：

```bash
nix run .#nixosConfigurations.wsl.config.system.build.tarballBuilder -- --wsl
```

## 与独立仓的关系

[DotRedstone/nixos-wsl](https://github.com/DotRedstone/nixos-wsl) 仍保留作模板，不删除、不归档。个人配置以本目录为准，日常 `NH_FLAKE` 不再指向 `~/nixos-wsl`。

## 验证

```bash
nix eval --raw .#nixosConfigurations.wsl.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.wsl.config.networking.hostName
nix eval .#nixosConfigurations.wsl.config.programs.nh.flake
```

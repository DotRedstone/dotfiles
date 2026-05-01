# 日常维护 (Maintenance)

## 常用命令

### 部署更新
- **Home Manager (hms)**: `home-manager switch --flake .#dot@warden`
- **NixOS Rebuild (nrs)**: `sudo nixos-rebuild switch --flake .#warden`

### 检查与验证
- **模拟构建**: `home-manager build` 或 `nixos-rebuild dry-run`。
- **全局语法检查**: `nix flake check .`。

## 重启与重载 (Reload)

### 什么时候需要 Reboot？
- 更新内核 (kernel)。
- 更新引导加载程序配置 (bootloader)。
- 更新涉及基础驱动 (如 GPU) 或文件系统挂载的改动。

### 软件重载
- **Fcitx5**: 若配置未生效，可运行 `fcitx5 -r -d` 重新加载。
- **Noctalia**: 修改 user templates 后，通常通过 `noctalia-shell` 触发同步，或重启对应的 Home Manager 服务。

## Git 提交规范

本仓库采用 Conventional Commits 规范，并要求**使用中文描述**。

### 格式
`<type>(<scope>): <中文描述>`

### 示例
- `fix(fcitx5): 修复 Rime 快捷键冲突`
- `feat(niri): 添加新的窗口规则`
- `docs(repo): 更新维护指南`

## 回滚与风险
- NixOS 会在引导菜单保留旧版本，若更新导致无法进入桌面，请在启动时选择上一个版本。
- 修改 `persistence.nix` 前务必执行 `dry-run`，并确保 `/persist` 分区已正确挂载。

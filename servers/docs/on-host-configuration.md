# 在服务器上维护 NixOS 配置

每台已受管主机的 `dot` 用户都有一个只检出 `servers/` 目录的 Git 工作副本：

```bash
cd ~/servers
git status
git pull --ff-only
```

`~/servers` 是 `~/Projects/dotfiles-servers/servers` 的快捷链接。工作副本指向
`DotRedstone/dotfiles` 的 `main` 分支，采用 sparse checkout，因此不会把桌面配置
带到服务器上。

## 修改与应用

先更新到最新提交，再在当前主机目录内修改一个职责明确的模块。例如 Hopper 的
JupyterHub 位于 `hosts/hopper/jupyterhub.nix`，Target 的服务位于
`hosts/target/services.nix`。

```bash
cd ~/servers
git pull --ff-only
git status

# 先做临时激活；保留当前可启动系统，确认第二个 SSH 连接和服务正常后再切换。
sudo nixos-rebuild test --flake .#hopper

# 确认无误后持久化到引导项。
sudo nixos-rebuild switch --flake .#hopper
```

将 `hopper` 替换为本机的主机名：`conduit` 或 `target`。硬件迁移和磁盘分区不是
日常编辑的一部分；涉及这些内容时，先阅读对应迁移文档。

## 提交配置

配置、模块和 SOPS 密文可以提交；运行数据、解密密钥、`.env`、数据库转储以及
`/nix/store` 中的文件绝不能提交。修改后先检查差异，再从任何已认证的 Git 工作站
推送：

```bash
cd ~/servers
git diff
git add hosts/hopper/jupyterhub.nix
git commit -m 'fix(hopper): 调整 JupyterHub 配置'
git push
```

服务器 checkout 以只读拉取为目标，不配置 GitHub 写入凭据；这样 SSH 主机失陷时
不会同时泄露仓库写权限。需要推送时，优先在个人工作站的完整仓库
`/home/dot/.dotfiles` 中完成。

## 回滚

如果 `switch` 后服务异常，选择上一个 NixOS generation，或通过 SSH 运行：

```bash
sudo nixos-rebuild switch --rollback
```

这只回滚系统 generation，不会抹掉 Git 工作副本中的未提交修改。先用 `git diff`
保存或提交变更，再处理配置差异。

## 未收编主机

`repeater` 仍没有完整原始 NixOS 源码，不能把仓库中不完整的配置当作它的现行配置
进行重建。它会保留独立的备份和盘点记录，待完整收编、影子构建验证后再加入上面的
日常重建流程。

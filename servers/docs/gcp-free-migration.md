# Google Cloud e2-micro 原子化迁移到 NixOS

本文对应主机 `gcp-free`（公网地址 `35.212.149.146`、区域
`us-west1-a`）。目标不是把旧 Debian 面板原样搬过去，而是只保留必要能力，
并让系统、服务、路由和密钥都能从仓库复现。

> Disko 会清空 `/dev/sda`。执行安装前必须验证设备名、备份和 SSH 公钥，
> 不要把本文命令直接套到另一台机器。

## 最终结构

```text
Internet
  └─ 443/tcp → Xray VLESS + REALITY
                  ├─ Cloudflare / Akamai / Fastly IPv4 → 原有 VLESS-WS 二级出口
                  ├─ 私网地址与 BitTorrent → 拒绝
                  └─ 其他目标 → GCP 直连

EasyTier 10.8.0.4 → 主动连接 47.110.239.66:11010
Komari            → 原生 Nix 包，禁用自动更新和远程 Web Shell
vnStat            → 月出站达到 180,000,000,000 字节后停止 Xray 与 EasyTier
```

主机防火墙默认拒绝，仅开放 `22/tcp` 和 `443/tcp`。EasyTier 不在这台机器
监听公网端口。Google OS Login 被关闭，SSH 用户完全由 Nix 配置管理。

## 配置边界

- `hosts/gcp-free/disko.nix`：`/dev/sda` 的 GPT、512 MiB ESP 与 ext4 根分区。
- `hosts/gcp-free/google-compute.nix`：GCE Guest Agent、virtio、MTU 与可移动
  EFI GRUB。
- `hosts/gcp-free/services.nix`：本机地址、上游节点和流量阈值。
- `modules/services/easytier.nix`：非 root EasyTier 服务。
- `modules/services/xray-gateway.nix`：REALITY 入站与 CDN 二级出口路由。
- `modules/services/komari-agent.nix`：沙箱化 Komari Agent。
- `modules/services/gcp-egress-guard.nix`：基于 vnStat 的本地熔断器。
- `secrets/gcp-free.yaml`：SOPS 密文，不包含任何明文凭据。

密文同时加密给工作站 age 身份和目标机现有 SSH Ed25519 主机密钥。安装时
必须保留主机密钥，否则新系统第一次激活时无法解密服务配置。

## 备份

迁移前备份位于：

```text
/home/dot/server-backups/gcp-free-20260904T172211Z/
```

其中包括：

- `gcp-free-20260904T172211Z.tar.gz.age`：旧 X-UI/Xray、DAE、Komari、TLS、
  SSH 主机密钥、vnStat 与系统清单。
- `gcp-free-reality-client.txt.age`：新 REALITY 客户端分享链接。
- 相应 `.sha256`：传输完整性校验。

验证：

```bash
cd /home/dot/server-backups/gcp-free-20260904T172211Z
sha256sum --check gcp-free-20260904T172211Z.tar.gz.age.sha256
sha256sum --check gcp-free-reality-client.txt.age.sha256
```

查看新客户端链接：

```bash
age --decrypt \
  --identity /home/dot/.config/sops/age/keys.txt \
  gcp-free-reality-client.txt.age
```

不要把解密后的分享链接、Komari token、EasyTier 密钥或 Xray 私钥提交到 Git。

## 安装前检查

```bash
ssh dot@35.212.149.146 '
  uname -m
  findmnt -n -o SOURCE /
  lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
  test -d /sys/firmware/efi && echo UEFI
  cat /proc/sys/kernel/kexec_load_disabled
'
```

这台机器已确认应显示：

- `x86_64`
- 根分区 `/dev/sda1`
- 系统盘 `/dev/sda`，容量 30 GiB
- UEFI
- `kexec_load_disabled` 为 `0`

本地验证配置：

```bash
nix flake check path:/home/dot/.dotfiles/servers
nix build \
  path:/home/dot/.dotfiles/servers#nixosConfigurations.gcp-free.config.system.build.toplevel
nix build \
  path:/home/dot/.dotfiles/servers#nixosConfigurations.gcp-free.config.system.build.diskoScript
```

## 安装

### 普通内存服务器

目标账号需要临时的免密码 sudo。用 `sudo visudo` 创建并校验
`/etc/sudoers.d/99-nixos-anywhere`：

```sudoers
dot ALL=(ALL:ALL) NOPASSWD: ALL
```

然后从工作站执行：

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake 'path:/home/dot/.dotfiles/servers#gcp-free' \
  --target-host dot@35.212.149.146 \
  -i /home/dot/.ssh/id_ed25519 \
  --copy-host-keys \
  --build-on local \
  --ssh-option StrictHostKeyChecking=yes \
  --ssh-option ServerAliveInterval=15 \
  --ssh-option ServerAliveCountMax=8
```

`--copy-host-keys` 既避免 SSH 指纹变化，也是 SOPS 首次解密的必要条件。

### e2-micro 的低内存处理

这台实例只有约 970 MiB 可见内存。当前 25.11 安装器的 initrd 约 406 MiB，
实际验证会在 `kexec_file_load` 阶段 OOM；使用 swap 仍无法解决内核为 Kexec
镜像分配页的问题。可改用 nix-community 官方 24.11 临时安装器，其 initrd
约 320 MiB。它只负责进入安装环境，最终安装的仍是本仓库锁定的新版 NixOS。

先在旧系统创建临时 swap 并停掉非必要服务：

```bash
ssh dot@35.212.149.146
sudo fallocate -l 2G /swapfile
sudo chmod 0600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
sudo systemctl stop x-ui komari-agent dae unattended-upgrades
sudo sync
echo 3 | sudo tee /proc/sys/vm/drop_caches
```

在工作站获取旧版临时安装器：

```bash
nix store prefetch-file --json \
  https://github.com/nix-community/nixos-images/releases/download/nixos-24.11/nixos-kexec-installer-noninteractive-x86_64-linux.tar.gz
```

将命令返回的 `/nix/store/...tar.gz` 传给 `--kexec`，并强制兼容 Kexec
syscall：

```bash
nix run github:nix-community/nixos-anywhere -- \
  --kexec /nix/store/REPLACE_ME-nixos-kexec-installer-noninteractive-x86_64-linux.tar.gz \
  --kexec-extra-flags '--kexec-syscall' \
  --flake 'path:/home/dot/.dotfiles/servers#gcp-free' \
  --target-host dot@35.212.149.146 \
  -i /home/dot/.ssh/id_ed25519 \
  --copy-host-keys \
  --build-on local \
  --no-disko-deps
```

如果 Kexec 已经手动完成，可以从工作站只执行剩余阶段：

```bash
nix run github:nix-community/nixos-anywhere -- \
  --phases disko,install,reboot \
  --flake 'path:/home/dot/.dotfiles/servers#gcp-free' \
  --target-host root@35.212.149.146 \
  -i /home/dot/.ssh/id_ed25519 \
  --copy-host-keys \
  --build-on local \
  --no-disko-deps
```

只有确认下面命令返回安装器信息后，才应执行剩余阶段：

```bash
ssh root@35.212.149.146 'grep VARIANT_ID /etc/os-release; free -h'
```

若临时安装器无法提供 SSH，不要继续下盘；从 Google Cloud 控制台重启实例，
它会从尚未修改的旧系统盘恢复。

## 安装后验收

等待重启完成后：

```bash
ssh dot@35.212.149.146 '
  hostname
  nixos-version
  systemctl --failed --no-legend
  systemctl is-active sshd xray easytier komari-agent vnstat
  sudo ss -lntup
  sudo iptables-save
  easytier-cli node
  easytier-cli peer
  gcp-egress-guard status
'
```

期望结果：

- hostname 为 `gcp-free`。
- 关键服务均为 `active`，没有失败单元。
- 公网监听只有 SSH 与 Xray 的 `443/tcp`；EasyTier 不监听公网端口。
- EasyTier 地址为 `10.8.0.4/24`，能看到现有 `.1/.2/.3` 节点。
- 防火墙只允许 `22/tcp` 与 `443/tcp`。
- 流量保护状态为 `clear`，阈值为 `180000000000`。

客户端导入备份目录中的加密分享链接后，分别测试普通网站以及
Cloudflare/Akamai/Fastly 目标。后者在 Xray 中固定走 `cdn-relay`，二级出口
失效时不会自动回落 GCP 直连。

## 日常更新

在工作站修改和验证配置，然后远程切换：

```bash
nix flake check path:/home/dot/.dotfiles/servers
nixos-rebuild switch \
  --flake 'path:/home/dot/.dotfiles/servers#gcp-free' \
  --target-host dot@35.212.149.146 \
  --use-remote-sudo
```

编辑密钥：

```bash
SOPS_AGE_KEY_FILE=/home/dot/.config/sops/age/keys.txt \
  sops /home/dot/.dotfiles/servers/secrets/gcp-free.yaml
```

如果更换整台 VM 或轮换 SSH 主机密钥，必须先把新主机公钥加入
`servers/.sops.yaml`，执行 `sops updatekeys`，再部署。

## 流量与计费边界

NixOS 只能控制来宾系统，不能修改 GCP 网卡的 Network Service Tier，也不能
代替 Cloud Billing Budget。迁移后仍需在控制台核对：

1. VM 位于免费层适用的美国区域和机型。
2. 网卡使用 Standard Tier，而不是默认 Premium Tier。
3. Billing Budget 与邮件告警已启用。
4. 云防火墙不保留旧脚本创建的 `0.0.0.0/0` 全端口规则。

本地 180 GB 熔断器按 vnStat 的物理网卡月 TX 统计；计费系统的口径可能与之
不同，所以预留了约 20 GB 安全空间。CDN IPv4 清单来自
[fatekey/gcp_free](https://github.com/fatekey/gcp_free/tree/f09a7316510494c59852a638a6a85af1e3fddc99)，
是静态列表，升级配置时应重新核对。社区实践可参考
[Linux.do 讨论一](https://linux.do/t/topic/628031) 与
[讨论二](https://linux.do/t/topic/816130?page=2)；政策和计费规则变化时，应以
控制台实际 SKU 与账单为最终依据。

## 回滚

- 普通配置更新失败：保持现有 SSH 会话，执行
  `sudo nixos-rebuild switch --rollback`。
- 新一代无法启动：在 GCP 控制台把系统盘挂到救援实例，切换
  `/nix/var/nix/profiles/system` 后重装 GRUB。
- 需要恢复旧服务数据：解密备份到权限为 `0700` 的临时目录，只恢复所需
  数据或参数，不要把旧 Debian systemd 单元和面板二进制直接覆盖到 NixOS。

迁移备份不是整盘镜像；Disko 执行后不能靠它恢复原 Debian 操作系统，只能
恢复本文列出的服务数据和密钥。需要整机级回滚时，应在控制台额外创建磁盘
快照。

# RackNerd 洛杉矶节点原子化迁移到 NixOS

本文对应主机 `conduit`（公网地址 `107.174.1.97`）。它记录了从 Ubuntu、
1Panel 和 Docker 迁移到原生 NixOS 的实机过程，也可以作为以后重装同一台
机器的操作手册。

> Disko 会清空 `/dev/vda`。执行写盘阶段前必须再次核对公网地址、系统盘、
> 加密备份和 SSH 主机密钥。不要把这些命令直接套到其他服务器，尤其不要
> 用于甲骨文云主机 `hopper`。

## 最终结构

```text
Internet
  ├─ 22/tcp             → OpenSSH，仅公钥，禁止 root 登录
  ├─ 80/tcp             → Nginx，保留原有两个订阅地址
  ├─ 20001/tcp          → Xray VLESS WebSocket
  └─ 20002/tcp          → Xray VLESS REALITY

Komari                  → 原生 Nix 包
```

旧 1Panel、Docker、3x-ui 和 OpenResty 不再安装。订阅由 Nginx 直接返回
SOPS 在运行时渲染的静态内容；Xray 也直接读取运行时生成的配置。防火墙默认
拒绝，只开放上面列出的端口。该国外节点不加入国内 EasyTier 网络，避免跨境
组网把国内节点带入额外的可达路径和故障域。TCP 使用 BBR 拥塞控制与 `fq`
队列调度。

## 配置边界

- `hosts/conduit/disko.nix`：`/dev/vda` 的 GPT、BIOS Boot 与 ext4 根分区。
- `hosts/conduit/networking.nix`：固定 IPv4、网关、DNS 与 `eth0` 命名。
- `hosts/conduit/platform.nix`：QEMU Guest 与 BIOS GRUB。
- `hosts/conduit/services.nix`：本机 Xray、订阅和 Komari 服务开关。
- `modules/services/xray-node.nix`：原生 VLESS WebSocket 和 REALITY。
- `modules/services/xray-subscriptions.nix`：Nginx 订阅端点。
- `modules/services/komari-agent.nix`：沙箱化 Komari Agent。
- `modules/server/tcp-bbr.nix`：共享的 BBR 与 `fq` TCP 调优。
- `secrets/conduit.yaml`：SOPS 密文，不包含可读凭据。

目标机的 SSH Ed25519 主机密钥先通过 `ssh-to-age` 转换成 Age recipient，再
写入 `.sops.yaml`。不能直接把 `ssh-ed25519 ...` 公钥作为这里的目标机
recipient；SOPS CLI 虽能使用它，`sops-nix` 的主机密钥导入路径却会转换成
原生 Age 身份，导致开机激活时无法匹配。

## 已验证硬件与网络

迁移前实机信息如下：

- x86_64 KVM，2 vCPU、约 2 GiB 内存。
- BIOS 启动、GPT 分区表。
- 唯一系统盘 `/dev/vda`，容量 30 GiB。
- IPv4 `107.174.1.97/26`，网关 `107.174.1.65`。
- 旧系统通过 `net.ifnames=0 biosdevname=0` 使用 `eth0`。

当前配置只适用于这些已核对的信息。云厂商更换磁盘、网关或启动方式后，
必须先改对应主机模块。

## 备份

迁移前的一致性加密备份位于：

```text
/home/dot/server-backups/conduit-20260905T002918Z/
```

`conduit-migration.tar.gz.age` 包括旧 1Panel、3x-ui 数据库、OpenResty 配置与
证书、Komari、Docker 数据、SSH 主机密钥和系统清单。备份时相关容器与服务
曾短暂停止，归档完成后又恢复运行，因此数据库内容是一致的。

安装前验证：

```bash
cd /home/dot/server-backups/conduit-20260905T002918Z
sha256sum --check conduit-migration.tar.gz.age.sha256
age --decrypt \
  --identity /home/dot/.config/sops/age/keys.txt \
  conduit-migration.tar.gz.age \
  | tar --gzip --list >/dev/null
```

不要把解密后的证书私钥、Komari token、EasyTier 密钥、Xray 凭据或订阅
地址提交到 Git。这个备份目前在工作站本地；还应另外复制到一个离线或异地
位置，避免工作站磁盘成为单点故障。

## 安装前检查

先确认 SSH 别名确实指向目标机，并保留严格主机密钥检查：

```bash
ssh -o StrictHostKeyChecking=yes conduit '
  hostname
  uname -m
  findmnt -n -o SOURCE /
  lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
  ip -4 -brief address
  ip -4 route show default
  sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
'
```

本地验证配置和安装脚本：

```bash
nix flake check path:/home/dot/.dotfiles/servers
nix build \
  path:/home/dot/.dotfiles/servers#nixosConfigurations.conduit.config.system.build.toplevel
nix build \
  path:/home/dot/.dotfiles/servers#nixosConfigurations.conduit.config.system.build.diskoScript
nix run github:nix-community/nixos-anywhere -- \
  --flake 'path:/home/dot/.dotfiles/servers#conduit' \
  --vm-test
```

目标账号在接管期间需要免密码 sudo。旧系统若尚未配置，应使用 `visudo`
创建临时规则并先运行 `sudo -n true` 验证；安装完成后旧系统磁盘会被清除。

## 两阶段安装

先只进入临时 NixOS 安装环境。这一步会中断业务和 SSH，但不写系统盘：

```bash
nix run github:nix-community/nixos-anywhere -- \
  --phases kexec \
  --flake 'path:/home/dot/.dotfiles/servers#conduit' \
  --target-host dot@conduit \
  -i /home/dot/.ssh/id_ed25519 \
  --copy-host-keys \
  --build-on local \
  --no-disko-deps \
  --ssh-option StrictHostKeyChecking=yes \
  --ssh-option ServerAliveInterval=15 \
  --ssh-option ServerAliveCountMax=8
```

等待临时环境上线，再检查一次。安装器中接口可能叫 `ens3`，最终系统会根据
配置恢复为 `eth0`：

```bash
ssh -o StrictHostKeyChecking=yes root@conduit '
  grep -E "^(ID|VARIANT_ID)=" /etc/os-release
  ip -4 -brief address
  ip -4 route
  lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS /dev/vda
  ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
'
```

只有操作系统显示 NixOS installer、地址和网关可用、磁盘仍为预期的
`/dev/vda`、SSH 指纹未变化时，才执行不可逆的写盘阶段：

```bash
nix run github:nix-community/nixos-anywhere -- \
  --phases disko,install,reboot \
  --flake 'path:/home/dot/.dotfiles/servers#conduit' \
  --target-host root@conduit \
  -i /home/dot/.ssh/id_ed25519 \
  --copy-host-keys \
  --build-on local \
  --no-disko-deps \
  --ssh-option StrictHostKeyChecking=yes \
  --ssh-option ServerAliveInterval=15 \
  --ssh-option ServerAliveCountMax=8
```

## 安装后验收

```bash
ssh -o StrictHostKeyChecking=yes dot@conduit '
  hostname
  nixos-version
  findmnt -n -o SOURCE,FSTYPE /
  ip -4 -brief address
  ip -4 route show default
  sysctl net.ipv4.tcp_congestion_control net.core.default_qdisc
  systemctl --failed --no-legend
  systemctl is-active sshd systemd-networkd nginx xray komari-agent
  sudo ss -lntup
  sudo sshd -T | grep -Ei \
    "^(PermitRootLogin|PasswordAuthentication|KbdInteractiveAuthentication|PubkeyAuthentication)"
'
```

期望结果：

- 根分区是 `/dev/vda2`，接口为 `eth0`，固定公网地址和默认路由正确。
- 五个关键服务均为 `active`，没有失败单元。
- 不存在 EasyTier 服务或 TUN 地址，`11010/tcp+udp` 不监听且被防火墙拒绝。
- 只监听 `22/tcp`、`80/tcp`、`20001/tcp` 和 `20002/tcp`。
- TCP 拥塞算法为 `bbr`，默认队列调度为 `fq`。
- root SSH、密码认证和键盘交互认证均关闭，公钥认证开启。
- 两个既有订阅地址返回原内容，未知路径返回 404。
- `xray-subscriptions-check.service` 为 `active`，确保订阅中的公网地址与主机声明
  一致后才允许 Nginx 启动。

Xray 的两个入站应继续使用迁移前的客户端配置。WebSocket 是兼容旧客户端的
保留方案；后续若改为 XHTTP，应作为单独变更，并先生成新客户端配置做并行
验证。REALITY 继续使用原端口，若出现网络侧封锁再单独调整，不应在迁移时
同时改协议和端口。

## 日常更新

工作站修改并验证后，可以直接远程切换，不需要重新运行 Disko，也通常不需要
重启：

```bash
nix flake check path:/home/dot/.dotfiles/servers
NIX_SSHOPTS='-o StrictHostKeyChecking=yes' \
  nixos-rebuild switch \
    --flake 'path:/home/dot/.dotfiles/servers#conduit' \
    --target-host dot@conduit \
    --elevate sudo
```

编辑密钥：

```bash
cd /home/dot/.dotfiles/servers
SOPS_AGE_KEY_FILE=/home/dot/.config/sops/age/keys.txt \
  sops secrets/conduit.yaml
```

若 SSH 主机密钥发生变化，先用 `ssh-to-age` 重新计算 recipient，更新
`.sops.yaml`，再运行：

```bash
SOPS_AGE_KEY_FILE=/home/dot/.config/sops/age/keys.txt \
  sops updatekeys --yes secrets/conduit.yaml
```

## 回滚

普通配置错误可在服务器上回退上一代：

```bash
sudo nixos-rebuild switch --rollback
```

也可以从 GRUB 选择上一代系统。网络、磁盘布局或引导配置变更应先使用
`nixos-rebuild test`，因为 SSH 断开后远程回滚不一定可用。

如果需要彻底回到 Ubuntu，只能从服务商控制台进入救援系统或重装镜像，再用
Age 身份解密备份并按需恢复 `/opt/1panel`、Docker 数据或证书。这会再次覆盖
磁盘，不属于普通 NixOS generation 回滚。

## 本次 Xray 复验与加固

2026-09-05 发现旧面板导出的 WebSocket 订阅仍把服务端写成 `127.0.0.1`。现已
改为 `107.174.1.97`，并增加声明式公网地址与启动前订阅校验，避免 SOPS 中的
静态订阅再次和主机配置漂移。

Xray 单元还移除了 `CAP_NET_ADMIN`，ambient capability 保持为空，并限制设备、
内核、控制组、命名空间、地址族等访问。`systemd-analyze security` 暴露评分从
6.1 降到 3.1。最终从公网订阅分别建立 WebSocket 和 REALITY 客户端连接，两条
线路均成功访问公网，出口地址均为 `107.174.1.97`；服务重启次数和新警告均为 0。

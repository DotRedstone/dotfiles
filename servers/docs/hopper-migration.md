# Oracle A1 应用服务器无 Docker 迁移到 NixOS

本文对应主机 `hopper`（公网地址 `140.245.62.36`），记录从 Ubuntu 24.04、
1Panel 和 Docker 迁移到原生 NixOS 的实机方案。它既是操作手册，也是对配置
边界、数据恢复和回滚条件的审计记录。

> `hosts/hopper/disko.nix` 会清空 `/dev/sda`。推荐先完成 OCI Boot Volume Backup、
> 工作站 Age 加密备份、ARM64 构建和恢复演练。本次机主明确跳过 OCI 快照，因此
> 写盘后只能依靠本地 Age 备份重建，不能一键回到旧 Ubuntu。

## 最终结构

```text
Internet
  ├─ 22/tcp             → OpenSSH，仅公钥，禁止 root 登录
  ├─ 80/tcp             → Nginx
  │   ├─ music.*        → Navidrome 127.0.0.1:4533
  │   ├─ openlist.*     → OpenList  127.0.0.1:5244
  │   ├─ oss.bdot.in    → RustFS S3 127.0.0.1:9000
  │   ├─ rustfs.bdot.in → RustFS UI 127.0.0.1:9001
  │   └─ sg-node.*      → 两条静态 Xray 订阅
  ├─ 20001/tcp          → Xray VLESS WebSocket
  └─ 20002/tcp          → Xray VLESS REALITY

Loopback only
  ├─ MySQL 8.4          → 127.0.0.1:3306
  ├─ PostgreSQL 18      → 127.0.0.1:5432
  ├─ MongoDB 8.2        → 127.0.0.1:27017
  ├─ Redis 8            → 127.0.0.1:6379
  └─ Aria2 RPC          → 127.0.0.1:6800，供 OpenList 离线下载

Komari                  → 原生、禁远程 Shell、禁自更新
```

目标系统不启用 Docker、Podman 或 containerd。删除 1Panel、3x-ui、OpenResty、
Artalk、AstrBot、FileCodeBox、Hermes/微信容器；OpenList AIO 自带的 Aria2 则改为
NixOS 原生服务，因为它是 OpenList 的实际运行依赖，不是独立业务。

## 配置边界

- `hosts/hopper/disko.nix`：`/dev/sda` 的 UEFI GPT、512 MiB ESP 与 ext4 根分区。
- `hosts/hopper/oci-platform.nix`：AArch64、virtio、systemd-boot 与 `ttyAMA0`。
- `hosts/hopper/networking.nix`：OCI DHCPv4、`eth0`、MTU 9000 和串口参数。
- `hosts/hopper/reverse-proxy.nix`：四组保留业务域名的 Nginx 反代。
- `hosts/hopper/services.nix`：本机服务开关与 Xray 端口。
- `modules/services/{openlist,navidrome,rustfs,mysql,postgresql,mongodb,redis}.nix`：
  七个原生服务的单一职责模块。
- `secrets/hopper.yaml`：Aria2、RustFS、MongoDB、Redis、Xray 和 Komari 的 SOPS
  密文。

SOPS 同时加密给工作站恢复身份和由旧机 SSH Ed25519 主机密钥派生的 Age
recipient。安装时必须使用 `--copy-host-keys` 保留这把主机密钥，否则新系统
无法解密服务凭据，SSH 指纹也会改变。

## 已核对的硬件与网络

- Oracle `VM.Standard.A1.Flex`，`aarch64`，4 vCPU，约 23 GiB 内存。
- KVM + UEFI；Oracle 串口为 `ttyAMA0`。
- 单块 200 GB Oracle BlockVolume：`/dev/sda`。
- 私网地址 `10.0.0.209/24`、网关 `10.0.0.1`，公网地址由 OCI NAT 提供。
- `eth0` 使用 DHCPv4，DHCP/DNS/metadata 地址为 `169.254.169.254`，MTU 9000。
- 旧系统允许 kexec；当前 SSH 主机密钥指纹为
  `SHA256:p1l6Zoj3o0x7e2CP93ryYbf3Vbe6wku2/SIPpBwPwEY`。
- 三把现有 SSH 登录公钥均已保留，其中 Oracle 初始化密钥仅授权给 `hopper`。

不要把公网地址写到 guest 接口；OCI 在 VCN 私网地址外做一层公网 NAT。静态写
`140.245.62.36` 会直接断网。

## 版本与数据策略

| 服务 | 旧容器 | Nixpkgs 锁定版本 | 恢复方式 |
| --- | --- | --- | --- |
| OpenList | 4.2.1 AIO | 4.2.5 | 停服复制 SQLite、配置和状态目录 |
| Navidrome | 0.61.2 | 0.63.2 | 停服复制 SQLite/WAL、缓存和音乐目录 |
| RustFS | 1.0.0-beta.1 | 1.0.0-rc.3 | 停服复制对象目录，保留原 S3 密钥 |
| MySQL | 8.4.9 | 8.4.11 | `mysqldump --all-databases` 逻辑备份 |
| PostgreSQL | 18.3 | 18.6 | `pg_dumpall` 逻辑备份 |
| MongoDB | 8.3.1，FCV 8.3 | 8.2.12 | `mongodump --archive --gzip`，禁止复用 WiredTiger 目录 |
| Redis | 8.6.3 | 8.10.1 | RDB 快照；认证密码轮换到 SOPS 文件 |

审计时 MySQL 没有业务库，MongoDB 只有 `admin/config/local`，PostgreSQL 有一个
非默认数据库，Redis RDB 仅 171 字节。四类数据库仍全部保留逻辑备份；MongoDB
不会为了系统库冒险复用不兼容的原始数据目录。OpenList、Navidrome 和 RustFS
的状态才是主要恢复对象。

旧 Redis 密码曾作为 Docker `Cmd` 参数出现，可被容器检查和进程参数读取；
新配置不沿用该值，改用新随机密码和 `requirePassFile`。

## TLS 与 Cloudflare

旧业务 vhost 实际只监听 `80/tcp`。公网 HTTPS 由 Cloudflare 终止，再以 HTTP
访问源站；对四个域名实测，Cloudflare 边缘与直连源站的状态和内容类型一致。
旧 `443/tcp+udp` 只是 1Panel 默认自签名页面，不承载这些业务，因此新系统不
开放 443，也不迁移那张 `localhost` 证书。

如果以后把 Cloudflare Origin 模式改为 HTTPS，应作为独立变更：先添加 DNS-01
ACME 或 Cloudflare Origin Certificate，再开放 443；不要在系统迁移时同时改变
TLS 拓扑。

## 备份与验证

当前工作站备份目录：

```text
/home/dot/server-backups/hopper-20260905T031127Z/
```

其中数据库逻辑备份均为 Age 密文：

```text
mysql-all.sql.gz.age
postgresql-all.sql.gz.age
mongodb.archive.gz.age
mongodb-admin-users.archive.gz.age
redis-dump.rdb.age
hopper-cold-app-state.tar.gz.age
hopper-hot-system-data.tar.gz.age
SHA256SUMS
```

在线应用归档只保留七个目标服务、3x-ui/Xray、OpenResty/Nginx、Komari、SSH
主机密钥与网络配置。明确废弃的 Hermes/微信数据约 16 GB，旧 1Panel 备份约
3.6 GB，均不纳入迁移包。

在线包完成后，又短暂停止 OpenList、Navidrome 和 RustFS，生成
`hopper-cold-app-state.tar.gz.age`。它只包含三个应用的可变状态；约 3.9 GB 的
只读音乐库复用已经校验的在线包，避免为了重复传输静态媒体延长停机时间。停机
前还通过 Navidrome 自带的 `backup create` 生成了一份一致性数据库备份。三个
容器随后全部恢复运行，并通过本机 HTTP 探测。

校验密文与归档：

```bash
cd /home/dot/server-backups/hopper-20260905T031127Z
sha256sum --check SHA256SUMS

age --decrypt \
  --identity /home/dot/.config/sops/age/keys.txt \
  hopper-hot-system-data.tar.gz.age \
  | tar --gzip --list >/dev/null
```

两个归档都已执行 Age 解密、原始 SHA-256 比对、完整 tar 遍历和
`SHA256SUMS` 校验。稳妥做法仍是在安装前创建 OCI Boot Volume Backup；本次实机
迁移由机主明确选择跳过，所以磁盘和引导故障只能依靠本地 Age 备份重建，不能
一键恢复原 Ubuntu 启动卷。

控制台中进入 `Storage → Block Storage → Boot Volumes`，选择 Hopper 当前挂载的
200 GB 启动卷，再进入 `Backups → Create Boot Volume Backup`。建议命名为
`hopper-pre-nixos-20260905`、类型选 `Full`；只有状态从 `CREATING` 变为
`AVAILABLE` 后才算完成。这里要创建的是启动卷备份，不是上传自定义镜像。

## 本地与 ARM64 验证

```bash
nix flake check --no-build path:/home/dot/.dotfiles/servers
nix build --dry-run \
  path:/home/dot/.dotfiles/servers#nixosConfigurations.hopper.config.system.build.toplevel
```

x86_64 工作站不能直接执行 ARM 构建结果。可在旧机的临时 Nix 容器中只读挂载
配置，完成 ARM 原生 `flake check`、系统闭包和 Disko 脚本构建；这只是迁移前
测试，最终 NixOS 不包含 Docker。也可以在 kexec 安装环境中使用
`--build-on remote`。

本次已经在 Hopper 的 AArch64 CPU 上完整构建系统闭包和 Disko 脚本，结果通过；
用于测试的 Nix、BusyBox 镜像和构建卷随后已删除，不会成为新系统依赖。

## 两阶段接管

官方 nixos-anywhere 对 aarch64 需要显式提供 ARM64 kexec image。工作站不能在
上游缓存缺包时补建 aarch64 derivation，因此直接使用 `nixos-images` 发布的 26.05
预构建包，并按发布页给出的 SHA-256 校验：

```bash
installer_dir=/home/dot/server-backups/hopper-20260905T031127Z/installer
kexec_image="$installer_dir/nixos-kexec-installer-noninteractive-aarch64-linux.tar.gz"

curl --fail --location --retry 3 --output "$kexec_image" \
  https://github.com/nix-community/nixos-images/releases/download/nixos-26.05/nixos-kexec-installer-noninteractive-aarch64-linux.tar.gz

printf '%s  %s\n' \
  210e7a385e73884218e3955b255d7eae66456782d44a373da9e59dd3058c1992 \
  "$kexec_image" | sha256sum --check
tar -tzf "$kexec_image" >/dev/null
```

旧 Ubuntu 上临时给 `dot` 配置免密码 sudo，并用 `visudo -cf` 校验。该规则只为
nixos-anywhere 接管存在，写盘后自然消失。

第一阶段只 kexec 到内存中的 NixOS 安装环境，不改分区：

```bash
nix run github:nix-community/nixos-anywhere -- \
  --phases kexec \
  --kexec "$kexec_image" \
  --flake 'path:/home/dot/.dotfiles/servers#hopper' \
  --target-host dot@hopper \
  -i /home/dot/.ssh/id_ed25519 \
  --copy-host-keys \
  --no-disko-deps \
  --ssh-option StrictHostKeyChecking=yes \
  --ssh-option ServerAliveInterval=15 \
  --ssh-option ServerAliveCountMax=8
```

重新上线后必须验证安装环境、网络、磁盘与主机密钥；任何一项不符都不要写盘：

```bash
ssh -o StrictHostKeyChecking=yes root@hopper '
  grep -E "^(ID|VARIANT_ID)=" /etc/os-release
  uname -m
  ip -4 -brief address
  ip -4 route
  lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS /dev/sda
  ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
'
```

只有看到 `aarch64`、预期 DHCP 私网地址、默认路由、`/dev/sda` 和原 SSH 指纹时，
才执行不可逆阶段。构建放在 ARM 安装环境中完成：

```bash
nix run github:nix-community/nixos-anywhere -- \
  --phases disko,install,reboot \
  --flake 'path:/home/dot/.dotfiles/servers#hopper' \
  --target-host root@hopper \
  -i /home/dot/.ssh/id_ed25519 \
  --copy-host-keys \
  --build-on remote \
  --no-disko-deps \
  --ssh-option StrictHostKeyChecking=yes \
  --ssh-option ServerAliveInterval=15 \
  --ssh-option ServerAliveCountMax=8
```

## 数据恢复顺序

新系统第一次启动后先停止应用与数据库，再恢复状态；不要让空实例和旧实例
同时写同一份数据：

1. 停止 Nginx、OpenList、Aria2、Navidrome、RustFS 和四个数据库。
2. 把旧 OpenList `data/` 恢复到 `/var/lib/openlist/`，属主设为
   `openlist:openlist`。
3. 把 Navidrome 的 `data/` 恢复到 `/var/lib/navidrome/`，音乐恢复到
   `/var/lib/navidrome/music/`，属主设为 `navidrome:navidrome`。
4. 把 RustFS `data/` 恢复到 `/var/lib/rustfs/`，属主设为 `rustfs:rustfs`。
5. MySQL、PostgreSQL 和 MongoDB 使用逻辑备份导入；MongoDB 不复制旧
   WiredTiger 文件。空库可以保留全新初始化状态。
6. Redis 停服后恢复 `dump.rdb` 到 `/var/lib/redis/`，再启动并使用 SOPS 中的
   新密码验证。
7. 依次启动数据库、RustFS、Navidrome、Aria2/OpenList、Xray、Nginx 和 Komari。

本次实机恢复时还做了两项兼容处理：

- Aria2 1.37 不接受空 RPC secret，因此生成新随机值保存进 SOPS，并同步更新
  OpenList SQLite 中的 `aria2_secret` 与回环 RPC 地址。
- MongoDB 源端只有系统库，且源版本 8.3 高于目标 8.2；全量逻辑备份继续保留，
  目标端使用新的 SOPS 管理员初始化，不把高版本系统元数据强行降级导入。

MySQL、PostgreSQL 和 Redis 的逻辑备份已实际导入；OpenList、Navidrome 和
RustFS 使用停服冷备恢复。Navidrome 音乐库从已校验的在线归档单独传输，以免把
其他旧 1Panel 文件重新带入新系统。

恢复后立即检查：

```bash
ssh dot@hopper '
  systemctl --failed --no-legend
  systemctl is-active \
    sshd nginx xray komari-agent openlist aria2 navidrome rustfs \
    mysql postgresql mongodb redis
  sudo ss -lntup
  sysctl net.ipv4.tcp_congestion_control net.core.default_qdisc
  sudo sshd -T | grep -Ei \
    "^(PermitRootLogin|PasswordAuthentication|KbdInteractiveAuthentication|PubkeyAuthentication)"
'
```

期望防火墙只放行 `22/80/20001/20002` TCP；数据库、Navidrome、OpenList、
RustFS 和 Aria2 不可从公网直连。再分别检查四个业务域名、两条订阅、两个 Xray
入站、OpenList 存储、Navidrome 曲库与 RustFS bucket/object 数量。

## 日常更新与回滚

```bash
NIX_SSHOPTS='-o StrictHostKeyChecking=yes' \
  nixos-rebuild switch \
    --flake 'path:/home/dot/.dotfiles/servers#hopper' \
    --target-host dot@hopper \
    --build-host dot@hopper \
    --elevate sudo
```

普通配置错误可以选择上一代或运行 `sudo nixos-rebuild switch --rollback`。磁盘、
引导或网络错误不保证能远程回滚，应使用 OCI 串口控制台；只有安装前实际创建了
OCI Boot Volume Backup，才能完整恢复旧 Ubuntu。本次没有该快照，只能使用本地
Age 备份重建。不要删除并重建 A1 实例来“回滚”，否则可能失去原 shape、容量或
公网地址。

## 本次实机结果

2026-09-05 已通过两阶段 nixos-anywhere 完成安装：第一阶段只进入 AArch64 kexec
环境并确认 DHCP、默认路由、磁盘和 SSH 指纹；第二阶段完成 GPT、ext4、
systemd-boot、SOPS 和系统闭包安装。首次启动后现场修正了 Aria2 RPC secret 与
MySQL X Protocol 的监听地址，并把 OpenList 的监听地址声明为
`127.0.0.1:5244`；三项均重新构建并热切换成功。

最终恢复与验收结果：

- Navidrome 音乐目录在本地与目标端均为 118 个文件、4,139,761,254 字节，Rsync
  全内容校验差异为 0；SQLite 完整性为 `ok`，曲库为 118 首、113 张专辑、78 位
  艺术家。
- OpenList SQLite 完整性为 `ok`，恢复 3 个用户和 1 个存储；RustFS 恢复 34 个
  用户对象、24,063,169 字节。
- MySQL 无业务库，PostgreSQL 恢复 1 个非默认数据库；MongoDB 新管理员认证与
  Redis 新密码认证均通过。
- 12 个目标 systemd 服务全部为 `active`，失败单元为 0；SSH 仍保持原主机指纹，
  仅允许公钥登录，BBR 与 `fq` 生效。
- 公网只可达 `22/80/20001/20002` TCP；应用与数据库端口均不可公网直连。五个
  Cloudflare 业务域名、两条 Xray 订阅和两个 Xray 入站全部通过探测。
- Docker、Podman 和 containerd 均不存在。迁移产生的本地与远端明文暂存目录已
  删除，只保留 4.7 GB 的工作站 Age 加密备份。
- 旧面板导出的 WebSocket 和 REALITY 订阅曾错误保留 `127.0.0.1`；现已改为
  `140.245.62.36`，并由 `xray-subscriptions-check.service` 在 Nginx 启动前验证。
  两条公网订阅均已实际建立客户端连接，出口地址与 Hopper 公网地址一致。
- Xray 单元已移除 `CAP_NET_ADMIN`，ambient capability 为空，并收紧设备、内核、
  控制组、命名空间和地址族权限；`systemd-analyze security` 暴露评分从 6.1 降到
  3.1，服务重启次数和新警告均为 0。

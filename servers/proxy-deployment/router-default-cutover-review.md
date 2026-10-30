# 路由器默认入口切换审查

状态：2026-10-18，完成两次受保护的临时入口切换与回退；
**当前 OpenClash 默认入口仍为旧配置**。本轮经 EasyTier SSH 通道操作，未要求
Warden 回到 LAN。LAN 终端实际流量仍待本地复验。
客户端隔离实例的实际出口和自动 provider 更新见
[交付 Worker 交接](./delivery-worker-canary-handoff.md)。

## 当前基线与兼容性

- OpenClash 已启用，UCI `config_path` 为
  `/etc/openclash/config/config.yaml`；该源文件 SHA-256 为
  `77f17fffe1b2c26ea930422695f4c578faf355153ae0bc14d045f7d70366e841`。
  运行配置是 `/etc/openclash/config.yaml`，两者内容不同；旧订阅与旧扫描任务仍在。
- 新交付的原始 router profile 已用路由器当前 `clash_meta -t` 检查通过，
  且与旧源配置的顶层字段集合相同。隔离实例的转换版也通过路由器测试，
  两地实际出口与 provider 自动更新通过。上述检查不覆盖 OpenClash 自身的配置改写。
- `/etc/init.d/openclash` 会按 UCI 选择源文件，复制到 `/tmp`、由 Ruby 解析，
  经过 `yml_change.sh`、`yml_rules_change.sh` 和现有自定义覆写脚本后，
  生成 `/etc/openclash/<配置文件名>` 并重建防火墙、dnsmasq 状态。
  路由器每天 03:00 有 OpenClash 重启任务。不能直接覆盖运行文件或仅用
  `clash_meta -t` 推断启动后的行为。
- 路由器约 492 MiB 内存。双核心隔离测试期间可用内存曾降到约 45 MiB，
  隔离实例停止后回升约 135 MiB。切换默认入口前须保持隔离实例停止，
  不让两套核心长期并行。
- 2026-10-18 的 20 分钟临时切换中，OpenClash 从 v2 源成功生成运行配置并启动；
  核心命令行指向生成文件，dnsmasq 正常。Controller provider `la-cf`、`sg-cf`
  均非空（分别 5、7 个节点）；生成配置含 11 组、62 条规则、TUN/DNS，且有
  OpenClash 注入的认证与覆写字段。通过生成后的认证 mixed-port 实测 LA/SG
  直连及 LA/SG CF 四种出口，均匹配各自预期出口；测试后恢复原运行模式及选组。
  此证据验证核心流量路径，不覆盖 LAN 终端的透明代理、默认路由与应用兼容。
- 首次切换期间，`cf-optimizer` 的 LA/SG 定时任务继续运行，但当时仅核对了
  本地 `staged=false` 与 nftables 的 `meta skgid 65534 return` 旁路规则，
  未单独读取控制 Worker 证实池更新。第二次切换前，实测 `nobody:nogroup`
  出口与批准的直连出口一致，并确认旧源、v2 源、回退脚本哈希及原 crontab。
  在重新建立的 20 分钟回退保护下启动 v2 后，旁路规则仍在，`nobody:nogroup`
  的实测出口仍与批准值一致。手动启动两地 `cf-optimizer` 任务后，本地 LA/SG
  各有 8 个测量结果、`staged=false`；其工作流仅在上传成功后才更新 current
  并清除 staged。经认证读取控制 Worker 的两份隔离池，`collectedAt` 分别推进到
  `2026-10-18T01:24:06Z`、`2026-10-18T01:24:31Z`，`validatedAt` 分别推进到
  `2026-10-18T01:24:21.805Z`、`2026-10-18T01:24:53.726Z`，通过验证的候选为
  6、5 个。该证据覆盖本次 v2 生效期间的直连测量和两地实际上传。
- 计时到期后 cron 于 2026-10-18 09:15:17（路由器本地时间）自动恢复旧入口，
  日志记录 `old OpenClash source and core restored`。当前 UCI 路径为旧源，
  SHA-256 仍为 `77f17fffe1b2c26ea930422695f4c578faf355153ae0bc14d045f7d70366e841`；
  core 与 dnsmasq 运行，回退 marker 和专用 cron 行均已清除。旧订阅文件仍在；
  当前经认证 Controller API 读取 35 个代理组状态；回退后比对备份快照确认的
  31 个 Selector `now` 一致。新 profile 文件及备份
  保留在路由器上供后续复核。
- 第二次切换在证据取得后，提前将截止时间调整为当前并执行同一回退脚本。
  旧 UCI 路径与源哈希、core、dnsmasq 均恢复；marker 已清除，移除专用 cron
  后完整 crontab 与备份逐字节一致。回退后 DNS 查询、旧代理的认证请求和
  31 个 Selector `now` 均通过，旧订阅未修改。
- 2026-10-18 只读检查确认脚本所用的 `/bin/stat`、`/usr/bin/sha256sum`、
  `/usr/bin/logger`、`/bin/pidof` 等绝对命令路径均存在。`/root` 位于可写的
  UBIFS overlay，状态文件预期跨普通重启保留；crond 当前运行、已启用且有
  `/etc/rc.d/S50cron` 启动链接。尚未重启实测这些条件，不能将其称为带外恢复。
  overlay 当时可用空间约 5.9 MiB，备份须限制为配置和状态小文件。

## 待执行的单入口切换窗口

1. 在路由器 root-only 目录保存 `/etc/config/openclash`、旧源配置、旧运行配置、
   `/etc/openclash/history/config.db`（如存在）、原 crontab，以及相关代理组的
   Controller `now`。记录当前 SSH、OpenClash、dnsmasq、NAT、DNS、旧订阅和
   Warden 普通流量基线；复核旧源哈希未漂移。
2. 将受限交付的原始 router YAML 安装为新的
   `/etc/openclash/config/v2-canary.yaml`，权限 `0600`，先运行路由器当前核心
   `-t`。保留旧源和旧订阅，不更新现用订阅的自动下载地址。
3. 在 `/root/proxy-v2-cutover/rollback.env` 写入旧/新源路径、旧源备份路径与
   SHA-256、UTC 截止 epoch；权限 `0600`。安装
   [`router-default-rollback.sh`](./scripts/router-default-rollback.sh) 为 root-only
   可执行文件，在 crontab 增加每分钟调用的一行。cron 当前已启用且运行；
   2026-10-18 已将脚本安装到 root-only 目录，执行无 marker 分支返回 0；
   临时加入的每分钟 cron 在下一分钟实际执行了该分支，删除专用行后与原 crontab
   逐字节一致；旧源哈希、UCI 路径和核心进程未变。该演练只证明调度与无标记分支。
   然后创建 `/root/proxy-v2-cutover/armed`，确认剩余回退时间至少 20 分钟。

   `rollback.env` 只接受以下 root 管理的字段；旧哈希和截止时间须在切换窗口
   重新计算，不能沿用本页的历史快照：

   ```sh
   OLD_SOURCE='/etc/openclash/config/config.yaml'
   NEW_SOURCE='/etc/openclash/config/v2-canary.yaml'
   OLD_BACKUP='/root/proxy-v2-cutover/config.yaml.before'
   OLD_SHA256='<旧源文件的 64 位 SHA-256>'
   DEADLINE_EPOCH='<UTC 截止 Unix 秒数>'
   ```

   cron 专用行使用 `* * * * * /bin/sh
   /root/proxy-v2-cutover/router-default-rollback.sh # proxy-v2-rollback`；
   安装前后比对完整 crontab，只增删这一行。
4. 仅改 `openclash.config.config_path` 指向新源文件并重启 OpenClash。
   回退 cron 不依赖 SSH 会话；即使连接中断，截止后也会将 UCI 路径恢复到旧源、
   必要时从备份恢复旧源正文，并重启 OpenClash。脚本只有在旧路径、旧哈希、
   旧运行配置的 core 进程和 dnsmasq 均通过基本检查时才删除 marker；
   不符时保留 marker 供下一分钟重试与排查。2026-10-18 已在旧配置副本上
   演练脚本等待 core 就绪并自动清除 marker；随后本轮 v2 临时切换的截止回退
   也由 cron 自动完成，确认旧 UCI 路径、源哈希、core、dnsmasq 后清除 marker。
   cron 在设备重启后仍会调度，但依赖 crond、文件系统和
   正确系统时间，不等于带外恢复。
5. 限时验收：核对 UCI 指向、运行文件名、core 进程、provider 两地数量与
   自动刷新、代理组 `now`、LAN 客户端 DNS 与默认路由、LA/SG 直连和 CF 出口、
   普通应用访问、旧订阅可读，以及 `cf-optimizer` 仍以 `nobody:nogroup` 从批准的
   直连出口测量并实际完成两地上传。
   对比切换前后内存和错误日志。全部通过且留有恢复时间时，先取消 crontab 的
   专用回退行，再删除 marker；保留备份至灰度观察结束。

两轮临时切换已验证 OpenClash 生成配置、四种实际出口、`cf-optimizer` 直连测量
与两地池写入，也已验证真实自动和手动提前回退。Warden 当时在外网，仍未验收
LAN 终端透明代理、DNS/默认路由和普通应用。当前保持旧默认入口；后续再次切换
须重新建立至少 20 分钟的 root-only 自动回退，并由 LAN 终端补齐这些验收项。

## LAN 终端验收入口

2026-10-18 只读核对：`repeater` 到路由器走 EasyTier `tun0`，其公网默认路由
走云服务器网卡 `ens5`，DNS 未指向路由器；它不能代表 LAN 终端。Warden 当时
从外部 Wi-Fi 上网，到路由器地址及公网的路径均经该 Wi-Fi，也不能代表 LAN
终端。经 EasyTier 连上路由器、在路由器本机发起请求或显式指定代理端口，
均不能证明 LAN 透明代理生效。

下一次窗口从实际接入该路由器 LAN 的终端执行以下检查，并保存切换前后的结果：

1. 用 `ip -4 route get 1.1.1.1` 确认普通公网流量以路由器 LAN 地址为网关；
   用 `resolvectl dns` 或系统对应命令确认当前 DNS 指向路由器。关闭终端自身的
   显式代理、VPN 和其他覆盖默认路由的隧道后再取样。
2. 重建至少 20 分钟的 root-only cron 回退，核对原 crontab、旧源哈希与备份；
   临时切到 v2 后，从该终端查询普通域名，并用不指定代理的 HTTPS 请求及常用
   应用验证可用性。取一条有明确目标的规则核对实际出口，再确认路由器核心、
   dnsmasq、provider、选组与 `cf-optimizer` 的直连测量/上传仍正常。
3. 若任何一项失败，立即执行已演练的回退脚本；全部通过且仍有恢复时间时，
   再决定是否保留 v2。回退时复核旧 UCI 路径、源哈希、core、dnsmasq、DNS、
   旧代理、31 个 Selector、marker 和完整 crontab。保留旧源、旧订阅及备份。

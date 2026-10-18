# 路由器默认入口切换审查

状态：2026-10-18，只读审查与回退脚本候选。**尚未切换 OpenClash 默认入口**。
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
   不符时保留 marker 供下一分钟重试与排查。该分支目前仅经过静态检查，
   **尚未实机演练**。cron 在设备重启后仍会调度，但依赖 crond、文件系统和
   正确系统时间，不等于带外恢复。
5. 限时验收：核对 UCI 指向、运行文件名、core 进程、provider 两地数量与
   自动刷新、代理组 `now`、LAN 客户端 DNS 与默认路由、LA/SG 直连和 CF 出口、
   普通应用访问、旧订阅可读，以及 `cf-optimizer` 仍从批准的直连出口测量。
   对比切换前后内存和错误日志。全部通过且留有恢复时间时，先取消 crontab 的
   专用回退行，再删除 marker；保留备份至灰度观察结束。

切换前仍须验证 OpenClash 生成后的配置与自定义覆写兼容，并演练回退脚本的
真实恢复分支；当前不具备把独立测试结果当作默认入口验收的依据。

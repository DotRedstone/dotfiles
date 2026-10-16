# v2 控制 Worker 隔离发布交接

状态：2026-10-16。本记录覆盖隔离控制 Worker 与路由器 `owner-campus-canary`
来源的实机验收。旧 Worker、旧 KV、旧订阅、CloudflareST 定时任务和路由器默认代理组
仍保持原状；私有配置已由独立交付 Worker 发布，客户端默认配置尚未切换。

## 当前部署

`servers/flake.lock` 将独立 `edge-proxy-worker` 固定到
`052a959dad36e4ea23ca45a1885c657761a5903c`。本地 `npm run check` 的格式、
类型和 53 项测试通过；`check-probe-inputs.mjs` 与两个入口的 Wrangler dry run
通过。这些检查不代替云端验收。

隔离控制 Worker `edge-preferred-v2-canary` 已上传版本
`86ab23f5-5d21-4549-9c0c-ddfe24f1ca91`，入口为
`preferred-v2-canary.dotdot.ggff.net`。它绑定独立 `PREFERRED_V2_STATE` KV
`e9ba26a96324492abee40b945754443f`，保留三项 Secret：
`SIGNING_KEYS_JSON`、`PREFERRED_READ_TOKEN`、`PROBE_ENDPOINTS_JSON`。
`workers.dev`、预览入口和 Cron 均关闭。交付 Worker 的独立域名与发布状态见
[交付 Worker 交接](./delivery-worker-canary-handoff.md)。

此次修复使受信任探测和固定 GitHub 抓取使用 `redirect: manual`，并显式拒绝
非 200 响应。先前的 `redirect: error` 在实际 Worker 中导致所有回源探测抛出
`fetch_error`；仅靠本地测试不能发现该边缘运行时差异。控制 Worker 只记录
固定失败类别，不输出候选地址、URL、凭据或异常原文。

## 路由器与池验收

路由器以 `nobody:nogroup` 运行扫描；OpenClash 的 `meta skgid 65534 return`
规则使该身份绕过代理。`cf-optimizer` 已升级到 `0.1.0-r2`，部署侧设置
`main.approved_egress_network` 为当前直连出口的 `ip:<公网地址>` 代号。
扫描前后和上传前均经 `https://ip.3322.net` 核对；代号不符或服务不可用时
停止，保留上次结果。故意设置错误代号的实机测试在扫描前被拒绝，恢复后
两地再次测量和上传成功。公网地址变化时需要重新核准代号，在此之前新扫描
会故障关闭。旧 CloudflareST 的两条定时任务和文件保持不变。

新增错峰 cron：LA 每小时 `0,30` 分、SG 每小时 `5,35` 分运行。2026-10-16
12:00 与 12:05 UTC 的任务已自动完成，路由器本地 staged 均为 false；
cron 进程与两条任务仍在，旧任务未修改。

路由器先用两个共同候选完成两地上传，均由控制 Worker 写入隔离 KV；随后恢复
原有 11 个候选种子并重新扫描。当前结果如下：

| 被测回源 | 路由器测得 | 可信跨地验证后写入 KV | 隔离来源 |
| --- | ---: | ---: | --- |
| LA | 8 | 5 | `owner-campus-canary/la` |
| SG | 8 | 6 | `owner-campus-canary/sg` |

读接口返回两份 v2 池，`validatedAt` 分别为
`2026-10-16T12:00:29.760Z` 与 `2026-10-16T12:05:40.682Z`。未通过回源验证的
候选被剔除；至少一项通过时只写入通过项，全部失败时保留旧池。路由器本地
staged 状态均已清除，上传保持开启。控制池有数据只证明隔离控制链路完成，
尚未证明发布器、交付 Worker、客户端或路由器默认组使用了这些数据。

## 服务器与后续边界

两台服务器的旧代理、旧订阅、Nginx、Xray、`proxy-origin-proof` 和
`proxy-preferred-probe` 均运行中。新增的公开 `/probe/uncached`、两地轮换后的
origin proof 凭据及对侧 `probe_env` 已逐机持久切换。Conduit 新闭包为
`6aj3yk1…`，Hopper 为 `x19gwa1…`；两台的 current、profile 和默认启动项
均指向各自新闭包，尚未重启。运行时密钥与加密 SOPS 来源匹配，新凭据通过
真实回源证明，旧凭据被拒；旧订阅正文与原内容一致。Hopper Gmail `/health`
返回 200。两台的一次性回退 timer 已停止，marker 已删除。

两台没有带外恢复入口，未通过重启测试验证新默认启动项的实际启动行为。
旧持久闭包仍包含已轮换的 proof 凭据，不应作为日常回退目标；紧急恢复时先
保护 SSH 与旧代理，再停用旧 `proxy-origin-proof` 和 `proxy-preferred-probe`。
[定时回退脚本](./scripts/optimizer-probe-rotation-rollback.sh) 已通过 `sh -n`、
`shellcheck` 和两机无 marker 的只读演练；两次 `switch` 均在 20 分钟保护下
完成，实机回退分支未执行。回退保护只覆盖未重启且 timer 可运行的窗口，
不等于带外恢复能力。

发布主机、交付 Worker 与隔离客户端实测见
[交付 Worker 交接](./delivery-worker-canary-handoff.md)。后续仍须验证各设备的
长期导入、更新和故障切换。
回退控制入口时只撤销隔离 Custom Domain 或回到已核对的上一版本；不要删除
隔离 KV，也不要改动旧 Worker、旧订阅或路由器默认组。若新探针失败，先停用
隔离上传并保留当前池；不要恢复已轮换的旧 proof 凭据。

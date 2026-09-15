# Cloudflare 节点原子化迁移

这份记录描述 2026-09-06 的现网审计结果，以及如何把路由器、Cloudflare Worker
和优选 IP 链路迁移到仓库中的最小实现。文中不保存任何 Token、UUID、密码、订阅
路径或旧 Worker 源码。

## 现网结构

两个 Cloudflare 账号已经按用途隔离：

- 节点账号负责代理 Worker、节点域名、KV、R2 和路由器订阅。
- 网站账号负责站点、Cloudflare for SaaS、自定义主机名和网站 Worker。

路由器的两个 Cloudflare provider 分别指向两个不同 Worker。主 provider 由 121 个
入口生成 WS、XHTTP、Trojan 三种传输，共 363 个节点；备用 provider 使用 99 个
优选入口。路由器每天运行 CloudflareST，再把前 100 个结果推送到公开 GitHub 仓库，
Worker 从该仓库读取入口列表。

这条链路能用，但职责没有收紧：路由器为了更新一份文本持有 GitHub PAT，测速时还会
停止 OpenClash；Worker 又同时承担代理、订阅、面板、日志、远程代码和配置管理。

## 审计结论

现网三个相关 Worker 均不建议继续扩展：

- 主 Worker 是约 1.38 MB 的单行混淆代码，主动关闭控制台输出，无法有效审阅。
- 备用 Worker 把 VLESS、Trojan、Shadowsocks、WS、XHTTP、gRPC、SOCKS、HTTP
  转发、加密、订阅转换、面板和 Telegram 集成塞进同一文件。
- 订阅 Worker 使用请求间共享的可变全局变量，并暴露可由参数控制的远程请求入口。
- 备用 Worker 的 KV 日志中有 1758 条记录；其中绝大多数 URL 查询串含看起来像
  Token、UUID、密码或密钥的参数。不要把这份日志复制到仓库或普通备份。
- Worker 绑定中的 UUID 和管理员口令使用明文变量，不是 secret binding。

最近七天的 Workers Analytics 自适应指标显示：主 Worker 约 37.3 万次请求、6.0%
错误率，CPU p50 约 75 ms、p99 约 2.21 s；备用 Worker 约 13.1 万次请求、6.1%
错误率，CPU p50 约 7.9 ms、p99 约 42 ms。自适应指标可能经过采样，只适合看量级
与趋势，但主 Worker 的 CPU 尾延迟已经足以支持重写决定。

## 新结构

```text
CloudflareST
    |
    | HMAC 签名 POST（无 GitHub PAT、不中断 OpenClash）
    v
Worker admin endpoint ----> KV preferred-endpoints-v1
                                  |
OpenClash subscription ----------+
    |
    +--> VLESS WS
    +--> VLESS XHTTP stream-one
    +--> Trojan WS
              |
              v
       cloudflare:sockets TCP
```

新 Worker 每项职责都有独立模块：协议解析、TCP/WS/XHTTP 转发、DNS UDP、优选 IP
存储、订阅生成与入口路由互不混合。它没有管理 UI、外部运行时代码、第三方订阅转换器、
请求明细日志或请求间共享的可变配置。

## Cloudflare 凭据

最初保存在 `/run/user/1000/` 的两枚 Account API Token 只有
`Read all resources`。2026-09-06 已由用户重新授权并验证为包含 Workers、KV、DNS、
证书等 163 项写权限。

- `account_id` + `api_token`：Wrangler 和 Cloudflare API 管理使用。
- `r2_access_key_id` + `r2_secret_access_key` + `r2_s3_endpoint`：只供 S3 兼容客户端
  操作 R2；它们不能替代 Cloudflare API Token。

生产凭据与新 Worker 的五项秘密现已加密保存到
`servers/secrets/cloudflare.yaml`，只允许工作站 Age 身份解密。临时 JSON 不提交，R2
密钥不会传给 Worker。两个账号继续使用不同 Token，以保持现有故障域隔离。

## 上线步骤

### 1. 本地验证

```bash
cd /home/dot/.dotfiles/servers/cloudflare/edge-worker
npm ci
npm run check
npx wrangler deploy src/index.ts \
  --name edge-proxy-next \
  --compatibility-date 2026-09-01 \
  --dry-run
```

### 2. 新建而不是覆盖

新建 KV namespace、新 Worker `edge-proxy-next` 和测试自定义域名。复制
`wrangler.example.jsonc` 为已忽略的 `wrangler.jsonc`，填入账号 ID、KV ID 和测试
域名。旧 Worker、旧 KV 和旧域名均保持不动。

### 3. 生成全新秘密

不要复用可能已经进入旧 KV URL 日志的 UUID、密码或路径。生成新的 VLESS UUID、
Trojan 密码、路由路径、订阅路径和 IP 上传 HMAC 密钥，通过 `wrangler secret put`
分别写入。具体变量名见 Worker README。

### 4. 并行接入路由器

先把新订阅作为独立 provider 加入 OpenClash，不修改现有默认代理组。验证：

1. VLESS WS 连通性和大文件下载。
2. VLESS XHTTP `stream-one` 连通性和长连接。
3. Trojan WS 连通性。
4. VLESS DNS UDP。
5. 优选 IP 更新后订阅节点数量与顺序。

### 5. 灰度

只把一个测试代理组切到新 provider，至少观察一天聚合错误率、CPU 时间和实际路由器
延迟。指标正常后再切默认组。回滚只需把代理组选择切回旧 provider，不需要回滚 DNS
或重新部署。

### 6. 清理

稳定后依次停用旧订阅、旧 Worker 和路由器 GitHub 上传任务，再吊销路由器上的 GitHub
PAT。最后轮换旧链路出现过的 UUID、密码和订阅 Token。

旧 KV 的日志很可能包含凭据。确认不需要安全取证后应直接删除对应键或整个旧 namespace；
不要下载到普通备份。删除不可恢复，执行前再次核对目标 Worker 和 KV ID。

## 暂不实现

管理面板、远程主题、在线编辑器、Telegram 访客日志、多订阅聚合、任意 URL 测速和动态
第三方源抓取都不是核心能力。以后确有需求时按独立模块加入，不进入转发热路径。

## 2026-09-06 灰度记录

- 创建 `edge-proxy-next-state` KV namespace。
- 部署 `edge-proxy-next`，绑定测试自定义域名与 5 项 Worker Secret。
- 从当前公开优选列表导入 100 个入口，生成 300 个订阅节点。
- 签名更新返回 204，伪造签名隐藏为 404。
- 真实边缘测试通过 VLESS WS、VLESS XHTTP `stream-one`、Trojan WS 与 VLESS
  DNS UDP。
- 实测发现 XHTTP 上传体结束时关闭 socket writable 会提前截断远端响应；当前实现改由
  响应泵最终关闭 socket，修复后完整 TCP 响应已验证。
- 路由器实测进一步发现 Mihomo 的 XHTTP 会规范化出尾斜杠，并在收到 HTTP 200 前等待
  请求体流。Worker 现在只兼容“精确路径”和“精确路径加一个尾斜杠”，且先返回响应流、
  后台解析握手；不会放宽到任意前缀。
- 当前 Mihomo 的 VLESS UDP 默认使用 XUDP Mux，而不是传统长度前缀。Worker 新增了只
  允许内层目标端口 53 的最小 XUDP 帧处理，任意其他 Mux/UDP 仍被拒绝；DoH 上游改用
  `dns.google` 主机名端点。
- 路由器已加入 `Abuse-CF-Next` provider 和独立的 `🧪 CF-Next-灰度` url-test 组；
  现有代理组均未引用该 provider，因此默认流量与原节点选择没有变化。
- OpenClash 运行时成功加载 300 个节点：100 个 VLESS WS、100 个 VLESS XHTTP、100 个
  Trojan WS。最终主动健康检查三类均为 100/100。
- 回环隔离的 Mihomo 灰度实例对三种传输分别取得 HTTPS 204，并各自完整下载 1 MiB；
  VLESS WS 与 XHTTP 的 XUDP DNS 均取得 `rcode=0`，运行日志确认 DNS 上游实际经灰度组。
- 路由器的 CloudflareST 更新器已改为 HMAC 签名直传 KV。活动脚本不再包含 GitHub
  地址或 PAT，`--upload-only` 实测成功，provider 主动刷新返回 204。
- 加入 `PROCESS-NAME,CloudflareST_proxy_linux_arm64,DIRECT` 规则后，最小测速测试退出码
  为 0；测速前后核心进程数一致，OpenClash 全程保持运行。
- 每日 `04:00` 的原定时任务路径不变，下一次执行会自动使用新更新器。
- 路由器上的源配置备份为
  `/etc/openclash/config/config.yaml.codex-before-cf-next-20260906`，旧更新器备份为
  `/root/cfst/run_cfst.sh.codex-before-edge-20260906`；两者权限均收紧为 `0600`。

若需要完整回滚，先恢复上述两个备份，再将活动更新器权限改回 `0700`，最后重启
OpenClash。旧更新器备份仍含旧 GitHub PAT；灰度稳定后应吊销 PAT 并删除该备份，
不要把它复制进 Git 仓库或普通备份。

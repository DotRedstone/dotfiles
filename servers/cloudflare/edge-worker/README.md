# Edge Worker

这是现有 Cloudflare 节点 Worker 的最小替代实现。它只保留当前链路真正使用的
能力，不包含管理面板、远程 UI、第三方订阅转换、访问日志或运行时抓取脚本。

## 当前能力

- VLESS over WebSocket
- VLESS over XHTTP `stream-one`
- Trojan over WebSocket
- VLESS DNS UDP（传统长度前缀及 Mihomo XUDP；仅目的端口 53，经 DoH 转发）
- KV 中的优选 IP 列表与 Base64/纯文本订阅
- 路由器使用 HMAC-SHA256 签名更新优选 IP
- 未知路径统一返回普通 404，不记录 URL、IP、User-Agent 或凭据

每个请求只使用自己的局部状态。Worker 全局作用域没有会被并发请求修改的配置，
也没有从 GitHub、远程 Pages 或订阅转换器加载运行时代码。

## 本地检查

```bash
cd /home/dot/.dotfiles/servers/cloudflare/edge-worker
npm install
npm run check
```

## 首次部署

当前节点账号、R2 凭据和 Worker Secret 已加密保存在
`servers/secrets/cloudflare.yaml`，只授权工作站的 Age 身份解密。部署脚本会查询或创建
独立 KV、生成临时 Wrangler 配置、上传 Worker 与 Secret，并在结束时删除所有临时
明文文件：

```bash
cd /home/dot/.dotfiles/servers/cloudflare/edge-worker
npm run deploy:dry-run
npm run deploy
```

脚本固定部署到新 Worker `edge-proxy-next` 和测试域名
`next-free.dotdot.ggff.net`，不会覆盖旧 Worker。以下五项始终作为 Worker secret 写入：

- `VLESS_UUID`
- `TROJAN_PASSWORD`
- `ROUTE_SECRET`
- `SUBSCRIPTION_TOKEN`
- `IP_UPDATE_KEY`

- `ROUTE_SECRET` 与 `SUBSCRIPTION_TOKEN` 使用至少 24 字节随机值的 base64url 文本。
- `IP_UPDATE_KEY` 使用至少 32 字节随机值。
- `PUBLIC_HOST` 是新 Worker 的测试自定义域名。

订阅地址是 `https://PUBLIC_HOST/sub/SUBSCRIPTION_TOKEN`。默认返回 Base64；追加
`?format=plain` 可在人工检查时得到分享链接，每次响应都禁止缓存。

## 路由器上传优选 IP

上传正文每行一个入口，支持以下格式：

```text
203.0.113.10#FRA
203.0.113.11,443,SIN
[2001:db8::10]:443#NRT
```

签名内容严格为 `Unix时间戳 + 换行 + 原始正文`，签名结果用小写十六进制：

```bash
timestamp="$(date +%s)"
body="$(sed '/^[[:space:]]*$/d' cloudflare_ips.txt)"
signature="$(printf '%s\n%s' "$timestamp" "$body" \
  | openssl dgst -sha256 -hmac "$IP_UPDATE_KEY" -hex \
  | awk '{print $NF}')"

curl --fail-with-body \
  -H "X-Edge-Timestamp: $timestamp" \
  -H "X-Edge-Signature: $signature" \
  --data-binary "$body" \
  "https://PUBLIC_HOST/admin/preferred-ips"
```

服务端只接受前后五分钟内的签名，列表上限 1000 项、正文上限 256 KiB。上传不再
需要 GitHub PAT，也不需要停止 OpenClash。

## 灰度与回滚

1. 用新 Worker 名称、新 KV 和新测试域名部署。
2. 在 OpenClash 中把新订阅作为独立 provider 加入，旧 provider 保持不动。
3. 分别验证 WS、XHTTP、Trojan、DNS UDP 和大文件下载，并观察至少一天错误率与
   CPU 时间。
4. 只切换代理组的默认选择，不立即删除旧 Worker。
5. 出现问题时把代理组切回旧 provider；这是即时回滚，不需要改 DNS。

确认稳定后再停用旧 Worker，并删除旧 KV 中含完整 URL 的历史日志。删除日志是不可
恢复操作，执行前应先确认不再需要安全取证。

## 当前灰度状态（2026-09-06）

- `edge-proxy-next`、独立 KV 和测试自定义域名已经创建。
- 5 项敏感绑定均为 `secret_text`，KV 使用独立 `kv_namespace` binding。
- 已导入当前 100 个优选入口，订阅生成 300 个节点。
- 真实 Cloudflare 边缘和路由器 Mihomo 数据面测试已通过 VLESS WS、VLESS XHTTP、
  Trojan WS 和 VLESS XUDP DNS。
- 三种传输均取得 HTTPS 204 并完整下载 1 MiB；WS 与 XHTTP 的 DNS 响应均为
  `rcode=0`。主 OpenClash 最终健康检查为三类各 100/100。
- 灰度中修复了 Mihomo XHTTP 的尾斜杠与响应时序兼容，并加入只允许 DNS 53 端口的
  XUDP Mux 最小解析；任意 UDP 转发没有因此开放。
- OpenClash 已加入 `Abuse-CF-Next` provider 和独立 `🧪 CF-Next-灰度` 组，运行时加载
  300 个节点；所有既有代理组均未引用它，旧节点选择和默认流量完全未变。
- 路由器更新器已使用签名接口替代 GitHub 上传，`--upload-only` 和 provider 主动刷新
  均已验证；CloudflareST 冒烟测试期间 OpenClash 全程保持运行。

## 统一 Mihomo Profile

Worker 同时发布 `router`、`desktop`、`mobile` 三份私有 Mihomo 配置。公共分流规则与节点
分组只维护一份，平台差异仅限端口、LAN 监听与 TUN 参数。导入方式、更新和回滚见
[`../../docs/mihomo-profiles.md`](../../docs/mihomo-profiles.md)。

- 路由器源配置与旧更新器保留了权限为 `0600` 的回滚副本，具体路径和清理提醒见迁移
  文档。

## TODO

- 给路由器的 CloudflareST 上传脚本做 Nix/OpenWrt 独立模块。
- 灰度完成后加入最小化的 Worker Analytics 告警；不采集访问明细。
- 只有确有需要时再做只读状态页，管理 UI 不属于核心路径。

# Edge Proxy Worker 部署适配

本目录只维护此部署的 Worker 名称、域名、Cloudflare 账号与 SOPS 密钥来源、Mihomo
基线及路由器适配。协议实现、配置生成器、测试和 npm 依赖由独立项目
`/home/dot/Projects/edge-proxy-worker` 维护，接口见该项目的 `README.md` 与
`docs/architecture.md`。`scripts/pinned-source.mjs` 固定旧版完整 Git 提交
`e84f549df1293117ffcf6e47dcc8ff4e5f5f6b57`。部署时必须通过
`EDGE_PROXY_WORKER_LEGACY_REPOSITORY` 指向含此提交的受限本地 checkout；新的
独立项目克隆不包含旧提交。部署脚本用 `git archive` 导出该
提交到权限受限的临时目录，运行 `npm ci`，再使用其中的 `src/index.ts`、
`src/preferred-control.ts` 和 `buildProfiles({ baseline, providers })`。工作树中的后续改动
不会自动进入部署。

旧提交只保存在受限本地备份中；另一台机器必须先安全取得该旧 Git 对象，并显式
设置上述环境变量，才能重新部署旧 Worker。不得把旧历史导入新的独立项目远端。
修改固定提交时，
先检查独立项目接口和版本，再更新适配器引用并重新验证。Mihomo 基线保存在
`servers/clash/router-policy.json`，私有 provider URL、账号、令牌与密钥保存在
`servers/secrets/cloudflare.yaml` 的 SOPS 密文中，不进入独立项目。

## 本地验证与部署

需要 Node.js 22 或更新版本、npm、Git、tar、SOPS，以及可解密上述 SOPS 文件的本机
Age 身份。独立项目先运行 `npm ci && npm run check`；这里的部署适配运行：

```bash
cd /home/dot/.dotfiles/servers/cloudflare/edge-worker
export EDGE_PROXY_WORKER_LEGACY_REPOSITORY=/home/dot/Documents/Codex/edge-worker-release.zdIsNs2I/legacy-original-checkout
git -C "$EDGE_PROXY_WORKER_LEGACY_REPOSITORY" rev-parse --verify e84f549df1293117ffcf6e47dcc8ff4e5f5f6b57^{commit}
node --check scripts/pinned-source.mjs
node --check scripts/deploy.mjs
node scripts/deploy.mjs --dry-run
```

`--dry-run` 解密本地配置、生成四份 Mihomo 配置，并对主 Worker 和独立优选控制面执行
Wrangler 本地打包。它使用占位 KV ID，不调用 Cloudflare API，也不写 KV 或发布
Worker；因此不证明真实 binding、Secret 或客户端连接可用。脚本的临时配置与密钥文件
使用 `0600` 权限，退出时清理。实际部署需单独执行：

```bash
node scripts/deploy.mjs
```

主 Worker 单独恢复可使用 `node scripts/deploy.mjs --main-only --dry-run` 验证，
再运行 `node scripts/deploy.mjs --main-only`。该模式要求现有 KV namespace 已存在，
不上传 Mihomo 配置、不部署优选控制 Worker，也不重传本地 SOPS 中的七项 Secret；
Wrangler 会继承线上已有 Secret。执行前记录当前部署版本以便回退，执行后仍需
核对线上绑定和真实入口响应。

以上备份目录的父目录仅允许所有者访问。实际部署前应重新核对旧提交和 dry run；
若备份被移动，更新环境变量指向同一旧提交。省略环境变量时适配器会拒绝执行，
不会从新的独立项目克隆中猜测旧来源。

实际部署会查询或创建 `edge-proxy-next-state` KV，将四份私有配置写入
`clash/config/<profile>`，然后部署 `edge-proxy-next-recovery` 和
`edge-preferred-control`。主 Worker 同时绑定自定义域名，并确保同域名的
`/*` Worker Route 指向该服务。原 `edge-proxy-next` 服务保留，但本次修复前的
自定义域名请求返回 522，不能视为可用回退。2026-10-24 已验证主域名的扫描路径、
订阅、优选池和配置下载；临时 Mihomo 客户端已验证 WS、XHTTP、Trojan 的
HTTP 出口以及新优选入口的 VLESS/WS 连通。DNS UDP 与实际设备的默认组选择仍需验收。
改动链路前应记录当前域名绑定、Route 和 Worker 部署版本；若新部署异常，先恢复
这些记录中的映射，再按实际健康状态选择旧 provider。

## 绑定与路由器

主 Worker 使用 `EDGE_STATE` KV、`PUBLIC_HOST` 等普通变量，以及
`VLESS_UUID`、`TROJAN_PASSWORD`、`ROUTE_SECRET`、`SUBSCRIPTION_TOKEN`、
`PREFERRED_ENDPOINTS_TOKEN`、`CONFIG_TOKENS`、`IP_UPDATE_KEY` 七项 Secret。
独立优选控制面共用 KV，只接收 `PREFERRED_ENDPOINTS_TOKEN` 和 `IP_UPDATE_KEY`。
两个 Worker 都将 `PREFERRED_POOLS` 设置为 JSON 数组文本 `["la","sg"]`，
`DEFAULT_PREFERRED_POOL` 设置为 `la`。这保持现有 `la`、`sg` 路径与
`preferred-endpoints-v2:<pool>` KV 键，并让无 pool 的兼容路径和订阅继续使用 `la`。
两侧绑定必须相同；修改池名时还需核对路由器上传路径与已有 KV 数据。
同域名 Worker Route 是本次恢复实际流量所需的接入路径；部署脚本会在
Wrangler 发布主 Worker 后核对或修正该 Route。仅恢复自定义域名绑定不能证明
主域名可用，应同时验证 Route 的目标和线上响应。
具体接口及签名格式见独立项目 README。`scripts/router-cfst.sh` 是此部署的路由器
CloudflareST 适配模板，私有密钥只保留在路由器的 `/root/cfst/edge.env`（`0600`）。
日常重测以当前池为输入；指定 `CFST_SEED_FILE` 做完整候选扫描时，模板同时带入
当前池地址参与探测。CSV 中仅有延迟、没有有效下载速度或低于 `CFST_MIN_SPEED` 的
地址不会发布。只有合格数量达到 `CFST_MIN_RESULTS` 且签名上传成功后才替换本地结果；模板变更
不会自动更新路由器现用脚本。
`node scripts/show-clash-profile-urls.mjs` 会输出含私有 token 的下载地址，只能在受信任
终端手动使用，不能写入日志或工单。

历史灰度记录与路由器回退路径见
[`../../docs/cloudflare-edge-migration.md`](../../docs/cloudflare-edge-migration.md) 和
[`../../docs/mihomo-profiles.md`](../../docs/mihomo-profiles.md)。

## 未知路径入口防护

[`waf-path-guard.json`](./waf-path-guard.json) 定义主 Worker 自定义域名的 WAF 规则：
只允许现有代理传输、订阅、优选池、配置和签名上传的路径前缀及对应 HTTP 方法进入 Worker，
其余请求由 Cloudflare 在 Worker 运行前拦截并返回 403。当前账号不支持 WAF
自定义响应，因此不能将拦截结果伪装成 404。前缀内仍由 Worker
校验令牌、方法和签名。主 Worker 的 `workers.dev` 与 Preview URLs 已关闭；
独立优选控制 Worker 的 `workers.dev` 仍开放，不受这条域名规则保护。

启用前须只读核对该域名的实际 Worker 绑定、现有 WAF 规则和合法客户端路径；
有请求分析权限时还应核对路径分布。部署后验证合法请求和扫描路径，并在具备
用量数据时比较 Worker 调用量。若误拦，在
Cloudflare 的 WAF 自定义规则中停用 `edge-proxy-next: 拦截未知路径或方法` 即可回退，
旧 Worker、KV 和订阅不需改动。此文件不会由旧版 `deploy.mjs` 自动发布，
WAF 规则须独立核对和管理。主 Worker 的 `workers.dev` 如需回退，可通过
Cloudflare Worker 域名设置重新启用；重部署前还需同步调整此脚本中的
`workers_dev` 与 `preview_urls`，以免声明配置再次覆盖线上状态。

`waf-v2-path-guards.json` 记录优选 v2 与配置投递 v2 的域名入口规则：
分别只放行 `GET /v2/preferred/`、`POST /v2/admin/`，以及 `GET /u/`。
这些规则按域名匹配；变更服务路径或方法时，先同步调整规则并验证合法请求。
误拦时可在 WAF 自定义规则中单独停用对应的 `edge-preferred-v2-canary`
或 `edge-delivery-v2-canary` 规则。

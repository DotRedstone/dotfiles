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

以上备份目录的父目录仅允许所有者访问。实际部署前应重新核对旧提交和 dry run；
若备份被移动，更新环境变量指向同一旧提交。省略环境变量时适配器会拒绝执行，
不会从新的独立项目克隆中猜测旧来源。

实际部署会查询或创建 `edge-proxy-next-state` KV，将四份私有配置写入
`clash/config/<profile>`，然后部署 `edge-proxy-next` 和 `edge-preferred-control`。
它可能改变现有灰度链路，须先复核固定源码、KV、测试域名和回退路径；本次迁移未执行。
Cloudflare 运行时验证还需分别检查配置下载、优选池更新、WS、XHTTP、Trojan、DNS
UDP 与客户端选择。旧 Worker、旧 KV 和旧 provider 在灰度期间保留，出现问题时将
OpenClash 选择组切回旧 provider；如需恢复旧部署脚本，可回退本目录迁移提交。

## 绑定与路由器

主 Worker 使用 `EDGE_STATE` KV、`PUBLIC_HOST` 等普通变量，以及
`VLESS_UUID`、`TROJAN_PASSWORD`、`ROUTE_SECRET`、`SUBSCRIPTION_TOKEN`、
`PREFERRED_ENDPOINTS_TOKEN`、`CONFIG_TOKENS`、`IP_UPDATE_KEY` 七项 Secret。
独立优选控制面共用 KV，只接收 `PREFERRED_ENDPOINTS_TOKEN` 和 `IP_UPDATE_KEY`。
两个 Worker 都将 `PREFERRED_POOLS` 设置为 JSON 数组文本 `["la","sg"]`，
`DEFAULT_PREFERRED_POOL` 设置为 `la`。这保持现有 `la`、`sg` 路径与
`preferred-endpoints-v2:<pool>` KV 键，并让无 pool 的兼容路径和订阅继续使用 `la`。
两侧绑定必须相同；修改池名时还需核对路由器上传路径与已有 KV 数据。
具体接口及签名格式见独立项目 README。`scripts/router-cfst.sh` 是此部署的路由器
CloudflareST 适配模板，私有密钥只保留在路由器的 `/root/cfst/edge.env`（`0600`）。
`node scripts/show-clash-profile-urls.mjs` 会输出含私有 token 的下载地址，只能在受信任
终端手动使用，不能写入日志或工单。

历史灰度记录与路由器回退路径见
[`../../docs/cloudflare-edge-migration.md`](../../docs/cloudflare-edge-migration.md) 和
[`../../docs/mihomo-profiles.md`](../../docs/mihomo-profiles.md)。

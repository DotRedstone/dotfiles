# 代理部署数据

本目录保存独立 `proxy-stack` Flake 所需的部署侧非密钥输入。新端点完成隔离测试和
审阅后才能发布；在此之前，现用的 `servers/proxy-accounts.json`、
`servers/clash/router-policy.json` 和订阅保持原有路径。

- `accounts.json` 的账户集合有意保持为空。现有账户仍由旧目录管理。迁移账户前，需核对
  `primaryOrigin`、两项批准的来源 ID、四种节点出口、生命周期元数据，以及分别
  存入 SOPS 的凭据。
- `nodes.json` 记录两处现有的公开节点端点和 Cloudflare 名称。REALITY 客户端参数
  与 WebSocket 路径属于私有运行时输入，不写入本文件。
- `preferred-sources.json` 登记路由器现用的两处独立 CloudflareST 来源。
  GitHub 来源需核对 owner、ref 和 path，并验证对应回源健康状态。
- `owned-domains.json` 仅保存直连规则所需的自有域名后缀和节点 IP。
- `profiles/` 分别保存路由器、桌面和移动端的网络行为。路由器配置保留现有的
  TUN、DNS、端口与控制器参数用于测试，尚未安装到路由器。

使用锁定版本编译器的 `validate` 命令检查本目录。生成的私有 YAML、token、
UUID、路径密钥与优选池快照不得进入 Git 或 Nix store。通用规则和编译器的
维护说明见独立项目 `/home/dot/Projects/proxy-stack/README.md`。

# 双节点代理分阶段发布记录

本页记录 2026-10-11 的本地实施状态。它不是现网发布令。`conduit`、`hopper`、
路由器和 Cloudflare 均未因本次工作执行服务切换。

## 本地变更

- 独立 `proxy-stack` Git/Flake 提供 11 个 Mihomo 策略组、按账户地区优先的两地
  CF fallback、两条手动 REALITY、受授权的手动 Worker、规则与配置编译器。
- Xray 模块从本地服务目录抽出为锁定 input；两台海外主机从部署侧传入旧账户目录，
  SOPS secret 名称、入站端口和旧身份保持原样。`target` 与 `gcp-free` 仍使用旧模块。
- 部署侧新增非秘密的账户、节点、来源、自有域名和三类客户端 profile 目录。
  新账户目录目前为空；旧 `proxy-accounts.json`、旧订阅、旧 Worker 和路由器配置可用。
- 三种 Worker 的独立 bundle 可从 `servers#proxyStackWorkerBundles` 的锁定修订构建。
  配置 Worker、优选控制 Worker 和参数化 CFST 脚本均未安装；优选控制的受信任
  回源探测服务绑定尚待实现与验收。

`servers/flake.nix` 通过私有 GitHub 仓库引入 `proxy-stack`，`flake.lock` 固定提交。
构建端须有该私有仓库读取权限；本机通过 Git HTTPS 认证已确认可读。只更新
`proxyStack` input，保留现有 `gmail-archiver` 锁文件改动。

## 已完成的本地验证

```text
proxy-stack: node --test test/*.test.mjs                 10/10 通过
proxy-stack: nix flake check path:.                      x86_64 通过
proxy-stack: sh -n + shellcheck router/run-cfst.sh      通过
部署目录: proxy-stack validate                           通过
测试身份: router/desktop/mobile 的 mihomo -t             3/3 通过
servers: nix flake check path:./servers --no-build      四主机求值通过
servers: nix build path:./servers#proxyStackWorkerBundles --no-link  三 bundle 构建通过
```

这些结果只证明语法、引用与构建。尚无真实账户凭据的直连/CF TLS 回源、应用登录、
大文件、订阅刷新或单账户撤销验证。路由器只读 SSH 拒绝当前密钥；Controller 返回 401，
现用策略组的 `now` 未能保存，因此路由器默认不得切换。

## 发布前检查与回滚

1. **锁与身份准备**：确认远程构建端的私有仓库读取权限；在 SOPS 建立隔离测试身份的两台独立
   UUID、订阅令牌、REALITY 客户端参数与 WebSocket 路径。构建端只能读锁定修订。
   回滚：将 `proxyStack` 锁回前一已验修订；首次引入时撤销 input 并恢复旧模块导入。
2. **受限灰度**：先在两台服务器 `nixos-rebuild test`，保持现有 SSH 会话与旧订阅；
   核对 Xray 监听、旧账户继续可用、测试账户两地 REALITY 和 CF 回源。受信任探测
   服务、私有 bundle 和 Worker 绑定通过测试后，使用新的 Worker 名称与路由发布，
   不覆盖旧 `/clash/`、`/sub/`。回滚：恢复服务器上一代配置并停用新路由/Worker；
   旧 Worker、订阅和旧 Xray 身份仍可使用。
3. **来源与路由器**：用签名上传和批准的 GitHub 路径各测一地成功/失败保留；
   先记录路由器所有相关组的 `now` 和活动配置带时间戳的副本，再添加新订阅。
   验证真实 Google、X、Telegram、ChatGPT、开发下载、YouTube 播放和 Minecraft
   登录/令牌刷新/进服，最后才把 `🚀 主线路` 选到两地优选。回滚：恢复旧订阅与
   配置备份、原策略组选项；读取运行时 `now`，确认出口与 DNS 恢复。

每一步发布前还需附具体 diff、目标 Worker/主机、访问方式、影响面与最终回滚命令。
未获得单阶段发布审阅前，不执行 Cloudflare、服务器或路由器变更。

# Cloudflare Edge

这里存放 Cloudflare 边缘侧的部署适配。它与各台 NixOS 主机配置分离：服务器
负责直连节点和应用，Worker 负责经 Cloudflare 的代理入口与订阅。

- `edge-worker/`：固定独立 `edge-proxy-worker` 提交，提供此部署的参数、SOPS 引用
  与路由器适配。通用源码和测试由独立项目维护。
- Cloudflare API Token、R2 密钥、UUID 和密码不得提交到 Git。
- Worker 变更先在灰度入口验证，保留旧 provider 作为回退路径。

详细部署、回滚和路由器优选 IP 上传方法见
[edge-worker/README.md](./edge-worker/README.md)。

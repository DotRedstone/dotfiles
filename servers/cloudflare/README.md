# Cloudflare Edge

这里存放 Cloudflare 边缘侧配置与代码。它与各台 NixOS 主机配置分离：服务器
负责直连节点和应用，Worker 只负责经 Cloudflare 的轻量代理入口与订阅。

- `edge-worker/`：无面板、无第三方运行时依赖的 Worker。
- Cloudflare API Token、R2 密钥、UUID 和密码不得提交到 Git。
- 生产 Worker 应先以新名称和新域名灰度，不覆盖现网 Worker。

详细部署、回滚和路由器优选 IP 上传方法见
[edge-worker/README.md](./edge-worker/README.md)。

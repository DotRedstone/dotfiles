# 统一 Mihomo 配置

本仓库把 Clash/Mihomo 的规则、代理分组和 DNS 策略集中维护，并发布四个独立凭证入口：
`router`、`desktop`、`mobile`、`root`。前三个入口下发当前路由器基线；`root` 下发已验证的
Android 热点基线。配置成品
不提交到 Git：其中包含订阅地址，只保留在
Cloudflare KV 中，并由不可预测的私有 URL 读取。

## 结构

```text
加密订阅源 + CF-Next 节点订阅
             |
             v
  当前路由器策略基线 + Android 热点基线
             |
             +-- router / desktop / mobile / root
                 独立凭证；root 保留 Android 的 TProxy/UID 参数
```

所有版本共享以下选择组：

- `🌐 Default`：日常默认出口，通过稳定故障转移链自动选择。
- `🛡️ 自建`：洛杉矶与新加坡原生节点。
- `☁️ CDN`：既有 CDN 节点与独立的 `🧪 CF-Next 灰度`。
- 分类组：ChatGPT、AI、开发、流媒体、通讯、社交、Apple、Google、Microsoft、Cloudflare、游戏。

国内与私有网络直连；境外规则、未命中流量由 `🚀 默认` 处理。DNS 使用 fake-ip，国内与
境外域名分别走对应 DoH；境外 DNS 会经 `🚀 默认`，避免直连解析泄漏。

## 节点组与 CF-Next 灰度

默认出口是 `🛟 稳定故障转移`：先使用原有 `♻️ 全节点自动`，其当前节点失效会依次退到
`♻️ 自建-自动`、`♻️ 滥用-自动`。所有测速组的失败阈值为一次、健康检查超时为五秒，避免已
失效节点长时间卡在选择结果里。策略组选择会持久化，不会因订阅刷新或重启而悄悄变更。

`🧪 CF-Next-灰度` 是独立的 Worker 节点池，不参与 `♻️ 全节点自动`。它不再将三种
传输混在一个延迟池中：优先 VLESS XHTTP，失效后回退 VLESS WS，最后才使用 Trojan WS。
每种传输各自测速，避免某个偶然低延迟但长连接抖动的 Trojan 节点被误选。灰度步骤是：

1. 在 UI 中将 `☁️ cloudflare` 选择为 `🧪 CF-Next-灰度`，只验证 Cloudflare 规则命中的流量。
2. 确认稳定后，将 `🌐 Default` 切为 `🧪 CF-Next-灰度`，进行全局灰度。
3. 出现异常立即将 `🌐 Default` 切回 `🛟 稳定故障转移`；不需重新导入订阅。

## 取得导入地址

在仓库中运行：

```bash
cd /home/dot/.dotfiles/servers/cloudflare/edge-worker
npm run clash:urls
```

它只在本机解密后打印四个私有导入地址。四者使用不同凭证：单一设备配置泄漏时可以只轮换
对应凭证，而不影响其他设备。不要把输出粘贴到公开聊天、截图或 Git 仓库。

## 客户端导入

- 任一普通 Mihomo 客户端：使用 `router`、`desktop` 或 `mobile` 对应凭证入口。
- Box for Root / Box4Magisk / KernelSU：使用 `root` 地址。它保留了用户已验证的
  Android 热点基线：`tproxy-port: 9898`、`redir-port: 9797`、DNS
  `0.0.0.0:1053`、`tun.device: meta`、Android UID 拦截与 `auto-redirect`，以及
  `external-controller: 0.0.0.0:9090`、`external-ui: ./dashboard`。因此
  `/data/adb/box/scripts/tproxy.conf` 必须使用 `PROXY_TCP_PORT=9898`、
  `PROXY_UDP_PORT=9898`、`DNS_PORT=1053`；热点透明代理必须设置
  `PROXY_HOTSPOT=1`。

## 更新与回滚

每次修改生成器或加密订阅源后运行：

```bash
npm run check
npm run deploy:dry-run
npm run deploy
```

先将新 profile 当作独立订阅导入测试。路由器采用 OpenClash 备份后再替换；失败时恢复原
配置即可。Worker 不保存客户端控制器密码，也不开放通用 UDP 转发。

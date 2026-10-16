# v2 控制 Worker 隔离发布交接

状态：2026-10-16。此记录仅覆盖 `proxy` 账户下的隔离控制入口；交付 Worker、
现用 Worker、旧 KV、旧订阅和路由器默认策略未切换。

## 已发布范围

`servers/flake.lock` 固定 `edge-proxy-worker` 提交
`ca217085f94dfec9e4d2512dbe78a98689fd721b`，NAR hash 为
`sha256-urg8FU+nzmLNscBv937ExvVrx9wIo/qzu1qlDKBaTGk=`。该提交修复控制
Worker 将中文接入网络标签从批准来源目录中跳过的问题。独立项目的
`npm run check` 通过；本仓库的 `check-probe-inputs.mjs` 和两个入口的
Wrangler dry run 通过。源码检查与云端发布分别验证。

控制 Worker `edge-preferred-v2-canary` 已部署版本
`22739626-630a-44e4-8e37-cc8c7fee57e4`，入口为
`preferred-v2-canary.dotdot.ggff.net`；Custom Domain ID 为
`49a5350288390321b31ed4cb386f044a1cb99b92`。它继续绑定独立
`PREFERRED_V2_STATE` KV `e9ba26a96324492abee40b945754443f`，保留
`SIGNING_KEYS_JSON`、`PREFERRED_READ_TOKEN`、`PROBE_ENDPOINTS_JSON` 三项
secret 及原有普通变量。`workers.dev` 和预览入口保持关闭；Cron 为空。
交付 Worker `edge-delivery-v2-canary` 仍未开放 Custom Domain。

公网验证对 `owner-campus-canary/la` 和 `/sg` 分别使用所属上传密钥：
正确签名但不合格的 `{}` 正文返回 422，错误签名返回 404。两地签名均通过
来源匹配阶段，说明中文接入网络标签不再导致来源被忽略；由于请求正文不合格，
它们没有触发可信候选探测或池写入。发布后控制 KV 仍为 0 键。域名、绑定、
关闭的子域状态及 KV 键数已由 Cloudflare API 读回核对。

## 待完成与回退

路由器已安装 `cf-optimizer` 后端和 LuCI 包，但 UCI 目标未填写、上传默认关闭、
候选文件为空；旧 CloudflareST 定时任务仍在运行。当前服务器入口只有私有签名
`/probe`，没有满足 `cf-optimizer` 的公开无缓存测速响应。OpenWrt 后端当前还
将两地上传共用一个 URL 和密钥，与控制 Worker 的地区隔离不匹配。这两项接口
修复需分别完成本地检查、受控部署和实机验收，之后才能从路由器生成两地真实
测量并写入新池。KV 为空时，不启用私有发布 timer 或交付入口。

新控制域名目前没有客户端消费者。若新入口异常，先停用上述精确 Custom Domain，
并检查旧 Worker、旧 KV 和旧订阅保持可用；需要恢复控制 Worker 代码时，先核对
旧版本 `dff9a19a-e96f-4965-9c99-7f3ea6fa3074` 的绑定和路由，再单独部署。
不删除独立 KV 或覆盖旧池。更新源码锁后，两地主机的声明式输出路径与已运行的
probe 系统闭包不同；本次 Worker 发布未重建或切换两地主机，不能把新锁视为
主机已升级。

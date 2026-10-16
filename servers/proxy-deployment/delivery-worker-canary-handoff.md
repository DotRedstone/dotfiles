# v2 交付 Worker 隔离发布交接

状态：2026-10-16。本记录只说明 canary 账户的独立配置交付。现用订阅、旧 Worker、
旧 KV 和路由器默认代理组未切换。

## 云端与运行时

`edge-delivery-v2-canary` 已部署版本
`340ed294-1394-48fc-a07b-9d963a0e5046`，使用独立 Custom Domain
`delivery-v2-canary.dotdot.ggff.net` 和 `DELIVERY_STATE` KV
`83b95ccf208f4c5e9a645df1c0200997`。`workers.dev` 关闭。交付令牌仅以
SHA-256 映射形式注入 Worker Secret；明文令牌、Cloudflare API token 与客户端
凭据只留在 SOPS 运行时中。

Conduit 的 `proxy/delivery_runtime` 是仅供发布器读取的 JSON；其中账户、两地
凭据、交付域名和独立 KV 绑定已在受限环境核对。公开目录不保存该运行时正文。
发布器使用锁定的 `proxy-stack` 修订 `5393d0e`。两地已验证池来自
[控制 Worker](./control-worker-canary-handoff.md)，文档写入和 manifest 切换
发生在独立交付 KV，不触及旧订阅。

Conduit 已启用 `proxy-delivery-publish.timer`，每 15 分钟执行一次发布。
Geo 数据固定到上游提交及哈希；发布脚本、只读目录和锁文件作为闭包输入
传到目标机，SOPS 运行时仍由 root 以 `0400` 读取。新闭包
`lgacjf7…` 经 `dry-activate`、临时 `test` 和持久 `switch` 验收，当前系统、
profile 与默认启动项一致；尚未重启。SSH、Nginx、Xray、两种探针及旧订阅
检查仍正常。发布服务首次运行写入五份文档，再次运行返回
`unchanged: 0 accounts, 0 documents`。前两次临时候选分别暴露了脚本相对
导入和闭包输入缺失；它们已实际回退，未成为持久系统。最终临时回退 timer
已在验收后停止。20:15 CST 的首次定时触发也返回
`unchanged: 0 accounts, 0 documents`。

## 实测范围

路由器按正常网络出口重新测量并上传两地候选后，发布器 `--check` 返回
`checked: 1 accounts, 5 documents`，随后 `--apply` 返回
`published: 1 accounts, 5 documents`。发布器逐份运行 Mihomo `-t`、写入后读回，
最后更新 `delivery/manifest/v1`。此前两地池超过一小时后的一次 `--apply`
被新鲜度检查拒绝，没有切换 manifest；此行为须保留。

从独立域名以 canary 令牌读取 router、desktop、mobile 配置及 desktop 的
LA、SG provider，五份均返回 HTTP 200 与 `Cache-Control: private, no-store,
max-age=0`，内容大小与 SHA-256 摘要分别核对。随机无效令牌返回 404。
这些结果证明隔离交付路径在该时点可用；未证明三类客户端已导入、自动更新
或实际走通每一种代理出口。

另在 Warden 创建仅监听回环的临时 Mihomo 进程，加载交付配置中的直连节点
及两地 provider 的前两个候选，不改变现用客户端。静态检查通过；经该进程
访问 HTTPS 出口身份服务时，LA 直连与两项 LA CF 候选均从 Conduit 公网出口
返回，SG 直连与两项 SG CF 候选均从 Hopper 公网出口返回，六次命令退出码为 0。
这验证了 canary 的四类出口可用；尚未验证路由器、桌面和移动端长期导入、
provider 自动更新、故障切换或账户撤销。

## 后续运行与回退

只有路由器能持续从正常出口刷新两地池，15 分钟发布 timer 才能持续生成新
manifest；池过期或发布失败时
旧 manifest 保持可读。客户端灰度需逐端验证 provider 更新和目标出口，
在此之前不要替换旧订阅或默认代理组。

回退本路径时停止 Conduit 发布 timer 或撤销交付 Custom Domain，保留独立 KV
供核查；旧 Worker、旧 KV、旧订阅及服务器上的旧代理继续服务。撤销账户需
另行修改交付令牌映射与 manifest，不能仅删除客户端配置。

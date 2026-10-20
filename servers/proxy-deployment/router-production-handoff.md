# 独立 router 账号交付记录

状态：2026-10-18，交付侧已发布；路由器默认入口仍由客户端灰度流程管理。
本文只保存可公开的部署证据。订阅令牌、两地 UUID、完整 URL 与回退快照
位于本机 `0700/0600` 私有状态目录，未进入 Git 或 Nix store。

## 主机身份

公开修订 `f3025b2` 登记默认关闭的 `router` 账户，仅在 Conduit/Hopper
主机层启用。两地 SOPS 分别保存独立的 `xray/managed_router_uuid`，旧账户
密文未改。私有 overlay 修订 `8d6616e` 锁定该阶段；Conduit 在 x86_64 构建，
Hopper 闭包在目标 ARM64 主机完成构建。

两地 `dry-activate` 只报告新增 UUID、修改 Xray 渲染配置和重启 Xray。
逐机持久 `switch` 前均安装了 root 专用脚本、精确闭包 marker 和限时回退
timer。Hopper 先切换；Conduit 激活时 SSH 断开，重连后确认切换完成。
两地主机的 current/profile、默认启动项、SSH/Nginx/Xray 正常，尚未重启。
Conduit 原有三条、Hopper 原有五条静态订阅均返回 HTTP 200，正文与原
SOPS 内容一致；两地新 UUID 与受限候选匹配。验收后停止主机回退 timer
并清理 marker。

## 交付发布

公开修订 `7bc6959` 仅在 Conduit SOPS `proxy/delivery_runtime` 中增加
`router` 账户与独立令牌，canary/test 字段不变。私有 overlay 修订
`05e2b14` 锁定该公开修订；Conduit 新闭包的 `dry-activate` 只报告修改
交付运行时。发布时使用限时保护暂停 publisher timer，并在本机受限目录保存
当前双账号 manifest、十份文档、Worker 元数据及旧哈希映射。目标 root
`0400` 运行时的 `--check` 通过后，先向 Worker 哈希映射添加 router，
再执行 `--apply`，返回 `published: 3 accounts, 15 documents`。
主机回退 timer 在发布 manifest 前已停止，避免旧双账号运行时与三账号
manifest 并存。

canary、test、router 的 router/desktop/mobile 下载均返回 HTTP 200；
router 的 LA/SG provider 分别返回 6/7 个节点，错误令牌返回 404。
`router.expiresAt=null`；`quotaGiB=50` 是声明元数据，未实时强制执行。
恢复 timer 后主动运行同一发布服务，返回
`unchanged: 0 accounts, 0 documents`，manifest 保留三账号。
13:15 CST 的下一次正常定时触发也返回相同的 unchanged 结果，服务状态成功；
其后 router 三种配置再次下载均为 HTTP 200。
在 Warden 以仅监听回环、关闭 LAN/TUN/DNS 的临时 Mihomo 配置分别选用
router 的 LA/SG 直连节点，两次 HTTPS 出口均匹配对应声明节点；进程已停止。
此证据不覆盖路由器 OpenClash 转换、LAN 应用流量、provider 自动更新
或默认入口切换。

本机 `0600` 客户端交接文件仅含 `urls.router`，路径为
`/home/dot/.local/state/proxy-router-account/router-20261018/router-handoff.json`。
路由器保护灰度完成后再导入；旧订阅与默认入口继续保留。

## 回退边界

正常 timer 可能更新旧账号文档版本。回退前重新备份当时的 manifest、引用
文档与 Worker 映射，不直接重放本次发布前快照。停用 router 时先停止
publisher timer、移除其 Worker 令牌哈希，再保留
`router.enabled=false` 的 manifest 记录并从运行时移除 router 令牌；
发布器不允许直接删除旧 manifest 中的账户。核对 canary/test 下载后恢复
timer。路由器已退回旧入口且不再使用 router UUID 时，才从两地主机撤销
该身份。旧账号、旧订阅和路由器默认组不因交付侧停用而删除。

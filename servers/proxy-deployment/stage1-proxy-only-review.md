# 双节点代理第 1 阶段源码候选

状态：2026-10-14 从已提交的 `main` `daaa777` 建立 `codex/stage1-proxy-only`。
本候选只包含代理行为，不含 Hopper Gmail 模块或 `gmail-archiver` 锁变更；
**不能直接用于 Hopper 的 `nixos-rebuild test/switch`**。

## 代理改动

行为提交 `a932344` 只涉及五个文件：`servers/flake.nix` 将已锁定的
`edgeProxyWorker` 输入传给 Conduit/Hopper；两地 `proxy/default.nix` 分别引入
同目录的 `canary-origin.nix`。主机模块把既有账户目录中的 `canary.enabled`
覆盖为 true，在现有 CDN TLS 虚拟主机启用精确 `=/proof` 路径与仅监听回环的
origin-proof 服务。Conduit 使用 `la-origin`，Hopper 使用 `sg-origin`。
旧 `guest`、订阅、Nginx 其他路由、Worker、路由器策略和 Target 不在本次 diff 中。
`servers/flake.lock` 与已提交 `main` 逐字节相同。

2026-10-14 的本地 `nix flake check path:./servers --no-build --all-systems
--option substituters ''` 通过四台主机及 x86_64/aarch64 Worker derivation 求值。
Conduit 顶层 derivation 为 `j4kq175rs5jnklahngasg95wz131p826`，对应输出
`ajayszz54z693qsrmvr6jc77n94gmcrp`，与前阶段 Conduit 完整构建和临时
`test` 所用闭包一致。Hopper 顶层 derivation 为
`qnk1a0sk8smsipl5xid1b3a6zm8d33x6`，对应输出
`yb9fahcxg9qlrjbyjfbmxl12xcr9vm1v`；这是前阶段发现 Gmail 漂移并回退的
原始最小候选。求值和路径相同不等于本轮重新构建或实机验收。

## Hopper 整机基线差异

| 来源 | Gmail 声明与锁 | 验证边界 |
| --- | --- | --- |
| 已提交 `main` 与本代理候选 | 仅声明 `gmail/imap_password` 和 `IMAP_PASSWORD`；无 `client_max_body_size 100m`；`gmail-archiver` 锁为 `b338d9c` | 不是上次 Hopper 运行配置的等价声明 |
| 2026-10-13 现场旧闭包 | 另有 `gmail/api_key`、`API_KEY`、100 MiB Nginx 上传限制；Gmail 二进制对应 `9e849bd` | 来自前阶段只读现网和旧闭包比对，不是本轮新检查 |
| 已验组合候选 `cd710b1` | 补齐 Gmail 两个 secret/环境变量、上传限制，并单独锁到 `9e849bd` | 曾完整构建和临时 `test`，Gmail API 与代理路径通过；未持久 `switch` |
| 主工作区未提交状态 | Gmail 模块已另行修改，锁指向 `e13e91b` | 属于其他工作；未审查兼容性，未纳入本候选或替使用者选定版本 |

前阶段直接激活原始最小候选时，Hopper 的 `gmail/api_key` 曾被移除，随后已回退；
见保留的 `codex/stage1-hopper-live-gmail` `cd710b1` 中
`servers/proxy-deployment/stage1-minimal-review.md` 和
`hopper-live-gmail-lock-review.md`。该分支及从中整理的组合候选
`codex/stage1-integration` `fbe9004` 保留先前验收证据，本候选不覆盖其历史。
Hopper 的 `test` 切换整个 NixOS 闭包，不能仅凭五个代理文件的范围忽略 Gmail 漂移。

## 组合与回退边界

先独立审查并提交 Hopper 现网基线候选，明确 Gmail 修订及其行为证据；主工作区
`e13e91b` 的未提交锁和 Gmail 改动不得直接拷入或覆盖。再以该基线和本代理行为
提交组合出新的整机候选，比较完整 `/etc`、SOPS secret 名称、Gmail unit/环境、
Nginx 路由、Xray 身份和订阅，并完成 Hopper ARM 构建。若选择此前已验的
`9e849bd` 组合，可复用其历史实机证据，但仍须重新核对现场状态；若选择
`e13e91b`，历史验收不覆盖该新 Gmail 二进制，需单独验证。

任何后续 `test` 前记录当场旧 `/run/current-system` 和开机 profile，确认 SSH 与
带外入口及固定截止时间的主机侧限时回退。失败时从现场旧闭包回退，并复测
`LoadCredential`、旧 `guest`、订阅、Gmail 与 SSH。2026-10-13 的组合候选
临时灰度已取消回退 timer，开机 profile 当时仍为旧闭包；这些都是历史状态，
不能当作 2026-10-14 的实时保障。本轮未连接服务器或修改 Cloudflare、DNS、
Worker、路由器和 Target。

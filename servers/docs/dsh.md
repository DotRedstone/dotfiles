# Hopper DeepSeek Harness（DSH）

## 状态与安全边界

这是独立草稿模块，不表示服务已构建、部署或可公网访问。主机入口导入模块，但
`dot.hopper.dsh.enable` 默认关闭；关闭时不会创建 DSH 用户、systemd 单元、Nginx
虚拟主机、监听、SOPS 字段需求或备份路径。

DSH 使用原生 Node 服务，不安装 Docker、Podman 或其他容器运行时。应用只绑定 IPv4
回环 3080。Cloudflare 模式下 Nginx 3081 也只绑定回环；仅当用户明确选择 EasyTier
并提供接口专属地址和 TLS 证书时，Nginx 才绑定该内网地址，并仅在该接口放行
3081/tcp。不会增加全局公网端口。

DSH 是开发者预览软件，能够执行模型生成的命令。独立的 `dsh` 系统用户和 systemd
沙箱能缩小权限，但不构成 VM、容器或完整安全隔离。不要把工作区链接到
`/etc/nixos`、管理员 home、数据库或其他服务状态；不授予 SSH、sudo、wheel、
restic、systemd-journal 或 Nix trusted-user 权限。模型 key、出网和工作区写权限
仍带来数据泄露、破坏性操作与 API 费用风险。

## 架构

~~~text
浏览器 → Cloudflare Access → 专用 Tunnel → Hopper Nginx 127.0.0.1:3081
                                           → DSH 127.0.0.1:3080

或客户端 → 已确认的 EasyTier + HTTPS → Hopper Nginx（接口地址:3081）
                                      → DSH 127.0.0.1:3080
~~~

DSH 自身认证必须保留。Cloudflare Access 是额外认证层，不能关闭 DSH launch-token/
session-cookie 认证。Tunnel 连接器默认关闭。Nginx 继承 Hopper
`recommendedProxySettings` 保留浏览器 Host，并启用 WebSocket 转发；不重复设置 Host。
Nginx access log 关闭，error log 仅保留 crit 级别并限制权限。DSH 运行日志
`/var/log/dsh/runtime.log` 可能含启动 URL 或过程凭据，只允许受限本机管理会话查看，
禁止贴入聊天、Issue 或 PR。

## 上游与原生打包

上游：<https://github.com/deepseek-ai/deepseek-harness>

核对的上游 README、CLI 参数和文档来自移动分支，不是不可变生产版本。该分支自报
版本为 `0.2.2-rc.1`、Node 要求为 `>=24.9.0`；这不能证明该版本已发布到 npm，
也不能证明 ARM64 运行行为或 CLI 参数。不得据此自动选版。

用户必须先指定已发布的精确 npm 版本（不得使用 `latest`），再生成并审查完整
`package-lock.json)，核对 resolved/integrity、Linux ARM64 原生依赖、Web assets、
插件与 Node engines。Nix 包使用锁定的 `nodejs_24`，不能忽略 engines，也不能在
服务启动时执行 `npx` 或联网安装依赖。

当前 package.json 的依赖版本是明确占位符，尚未生成 package-lock.json；版本未决定
时生成锁文件会伪造依赖版本与 integrity。Nix derivation 的 `npmDepsHash` 使用
`lib.fakeHash`，同样是占位符。选版后须更新 package.json、package-lock.json、
`upstreamVersion` 和真实 hash，并完成 ARM64 打包、`dsh --version`、
`dsh web --help`、无真实凭据的 Web 启动与认证冒烟测试。还要验证首次启动不会联网
安装插件或依赖；若上游无法禁用自动更新或插件市场，暂不允许上线。

当前模块中的 `web --host/--port/--no-open/--public-url/--trusted-host` 参数尚未对
用户选定的不可变版本做验证。不能宣称服务可运行。

## 待用户决定

| 项目 | 当前状态 | 约束 |
| --- | --- | --- |
| DSH 版本 | `upstreamVersion = null`；package.json 为占位符 | 选择精确发布版本，不得 latest |
| 域名 | `hostName = null` | 指定完整域名并检查占用 |
| 入口 | `ingress = null` | Cloudflare Tunnel + Access 或 EasyTier 二选一 |
| 模型 provider | 未配置 | 确认 provider、协议、Base URL、模型 ID 与预算 |
| 模型 key | 默认不注入 | 确认 provider 的环境变量映射后再设置 |
| EasyTier | 参数为空 | 仅内网模式提供接口名、地址与 TLS 证书 |
| 工作区预算 | 未设定 | 确认磁盘预算、监测告警与备份维护窗口 |

启用时检查精确版本、有效域名、入口与 Restic 备份。模型 key 的环境变量名和 SOPS
键名必须成对设置；两者都留空时不产生模型 key 的 SOPS 字段需求。

## SOPS 键名

以下仅列键名，不包含值。用户须在可信机器编辑当前 SOPS 密文；不要把私钥、明文 key、
解密 YAML 或 Age 身份文件发送给 ChatGPT。

| 键名 | 使用条件 | 读取方 |
| --- | --- | --- |
| `dsh/model_api_key` | 自定义 OpenAI 兼容 provider | DSH 专用 EnvironmentFile |
| `dsh/deepseek_api_key` | 确认使用原生 DeepSeek provider 后 | DSH 专用 EnvironmentFile |
| `dsh/openai_api_key` | 确认使用对应 provider 后 | DSH 专用 EnvironmentFile |
| `dsh/anthropic_api_key` | 确认使用对应 provider 后 | DSH 专用 EnvironmentFile |
| `dsh/cloudflare_tunnel_token` | Cloudflare 模式且 tunnelEnable=true | systemd LoadCredential，仅给 Tunnel |
| `dsh/mesh_tls_key` | EasyTier HTTPS 模式 | Nginx TLS 私钥读取路径 |

模块只声明显式选择的一个模型 key，不批量声明未使用字段。Tunnel 和 mesh 键也只在
相应模式启用时声明。provider 的 schema、Base URL、model ID 与 apiKeyEnv 映射必须按
选定的不可变版本确认，不能从移动分支推定，也不能把明文 key 写入 WebUI profile。

用户在可信机器执行 `cd servers && sops secrets/hopper.yaml`，只添加实际选择的加密
字段，保留现有键和 MAC。本 PR 不修改、创建或覆盖任何 `servers/secrets/*.yaml`。

## 数据目录与备份

| 路径 | 内容 | 策略 |
| --- | --- | --- |
| `/var/lib/dsh/home` | profile、设置、会话与可能的凭据 | 纳入一致性归档，视为敏感数据 |
| `/var/lib/dsh/workspaces` | 明确授权的工作区 | 纳入归档，禁止链接其他服务目录 |
| `/var/cache/dsh` | 可重建缓存 | 不备份 |
| `/var/log/dsh` | 可能含启动凭据的日志 | 不进入通用备份 |
| `/var/lib/restic/staging/dsh/dsh.tar` | 停写后生成的一致性归档 | 加入 hopper-local，再由现有任务镜像 R2 |

模块只在 enable 时向现有 `hopper-local` 追加独立 staging 路径与 prepare/cleanup，
不替换数据库导出逻辑，也不新增 R2 凭据。仅当 DSH 原本 active 时才停止；归档后恢复。
EXIT trap 处理正常错误路径，ExecStopPost 处理 prepare 被超时终止的恢复兜底。恢复失败
必须使备份失败，不能静默忽略。

上线后在维护窗口验证：

~~~bash
systemctl show restic-backups-hopper-local.service -p Result -p ExecMainStatus
sudo systemctl start restic-backups-hopper-local.service
sudo systemctl start restic-mirror-hopper-to-r2.service
sudo restic --repo /var/lib/restic/repositories/hopper \
  --password-file /run/secrets/restic/hopper_repository_password snapshots
~~~

恢复演练先由管理员人工选择快照 ID，不盲用 latest；在 root 私有临时目录恢复归档，
验证只含 dsh/ 相对路径后解压到演练目录，禁止覆盖线上目录。每月从 R2 做同版本隔离
恢复，使用临时用户或虚拟机、另一回环端口、不配置 Tunnel、不载入生产 key、不允许
出站模型调用。不能在生产 dsh 用户下用另一个 DSH_HOME 冒充隔离。

## Cloudflare 交接（本 PR 不执行）

1. 用户确认域名、本人 IdP 身份与会话时长；检查主机名占用。
2. 创建 Access self-hosted application，默认拒绝，只 Allow 用户指定身份；必要时 MFA，
   不使用 Bypass 或 Everyone。
3. 创建专用远程管理 Tunnel；用户在 Hopper SOPS 添加
   `dsh/cloudflare_tunnel_token`。
4. Tunnel 只把该主机名映射到 `http://localhost:3081`，保留 Host、支持 WebSocket；
   开启 Tunnel Access token 验证并绑定正确 audience。
5. Access 与 Tunnel route 验收后才创建或接管 DNS；禁用缓存，不记录认证 URL。
6. 验收未登录拒绝、非授权身份拒绝、本人登录后 DSH 自身认证仍生效；外部直连
   3080/3081 必须失败。

本 PR 不创建或修改 Cloudflare Access、Tunnel、DNS、Worker、Nginx 公网入口或全局端口。

## 验证与部署门槛

公开服务器 Flake 只导出 `lib.mkHopper`，不导出可直接部署的 Hopper 系统目标。
实际求值和构建必须走用户私有 overlay，并先锁定已审查公开提交。当前草稿未执行：

- `nix flake check path:./servers`
- 私有 overlay 的 check 与 Hopper 系统闭包求值
- ARM64 原生包构建、systemd/Nginx 生成配置检查
- DSH 无凭据启动、认证、WebSocket 与模型最小调用
- 备份停服成功/失败恢复测试及同版本隔离还原
- 外部端口扫描、Access 身份策略和 Tunnel 验收

未完成版本、锁文件、真实依赖 hash、ARM64 构建、认证冒烟和恢复演练前不得启用或部署。
须检查最终 Nginx 配置只设置一次 Host、WebSocket 正常、cookie Secure 正确、日志不含
启动凭据，且 DSH 用户不能访问主机配置、数据库或其他服务状态。

用户完成前置项后才在私有 overlay 显式启用，按 test → 验收 → switch 分阶段操作。
部署前记录旧系统闭包并保留第二个 SSH 会话；test 失败时用户手动激活旧闭包。
持久 switch 后回滚前先核对系统代次。代码回滚不会回退 DSH 数据格式，旧版本恢复
必须同时恢复匹配的数据副本。

## 风险

- DSH 开发者预览、未完成安全审计；模型生成命令可修改工作区并访问网络。
- key、启动 URL、会话与 profile 敏感；日志、备份和恢复目录必须受限。
- 版本或原生依赖不兼容可能导致 ARM64 启动失败；不能依赖启动时联网修复。
- 备份需要短暂停服；恢复失败、超时和服务恢复路径必须实测。
- Tunnel/Access 顺序错误可能暴露管理入口；必须先建立并验收 Access 拒绝策略。
- Hopper 与数据库、存储、代理共享资源；上线前确认磁盘、内存、CPU 与 API 预算。

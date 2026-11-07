# Hopper DeepSeek Harness（DSH）

## 状态与安全边界

这是独立草稿模块，不表示服务已构建、部署或可公网访问。主机入口导入模块，但
`dot.hopper.dsh.enable` 默认关闭；关闭时不会创建 DSH 用户、systemd 单元、Nginx
虚拟主机、监听、SOPS 字段需求或备份路径。

DSH 使用原生 Node 服务，不安装 Docker、Podman 或其他容器运行时。应用只绑定 IPv4
回环 3080。Cloudflare 模式下 Nginx 3081 也只绑定回环。EasyTier 入口目前 fail-closed
禁止启用：共享模块尚未提供可验证的设备接口绑定，不能仅凭用户传入接口字符串保证
监听地址属于 EasyTier。不会增加全局公网端口。

DSH 是开发者预览软件，能够执行模型生成的命令。独立的 `dsh` 系统用户和 systemd
沙箱能缩小权限，但不构成 VM、容器或完整安全隔离。不要把工作区链接到
`/etc/nixos`、管理员 home、数据库或其他服务状态；不授予 SSH、sudo、wheel、
restic、systemd-journal 或 Nix trusted-user 权限。模型 key、出网和工作区写权限
仍带来数据泄露、破坏性操作与 API 费用风险。

## 架构

~~~text
浏览器 → Cloudflare Access → 专用 Tunnel → Hopper Nginx 127.0.0.1:3081
                                           → DSH 127.0.0.1:3080

EasyTier 入口暂不可用，待共享模块提供可验证的接口绑定后另行实现。
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
`package-lock.json`，核对 resolved/integrity、Linux ARM64 原生依赖、Web assets、
插件与 Node engines。Nix 包使用锁定的 `nodejs_24`，不能忽略 engines，也不能在
服务启动时执行 `npx` 或联网安装依赖。

当前 package.json 的依赖版本是明确占位符，尚未生成 package-lock.json；版本未决定
时生成锁文件会伪造依赖版本与 integrity。Nix derivation 的 `npmDepsHash` 使用
`lib.fakeHash`，同样是占位符。选版后须更新 package.json、package-lock.json、
选定并锁定了精确发布版本 `@deepseek-ai/dsh@0.2.2-rc.1`，生成并审查了不可变
`package-lock.json` 与真实 `npmDepsHash`。在 aarch64 上完成了完整构建，且验证通过
`dsh --version` 与 `dsh web --help` 参数支持（包括 `--host`、`--port`、`--no-open`、
`--public-url` 与 `--trusted-host`）。

## 私有 Overlay 配置示例

在部署 Hopper 的私有 overlay（如 `hopper.nix`）中配置：

~~~nix
{ ... }: {
  dot.hopper.dsh = {
    enable = true;
    ingress = "cloudflare";
    tunnelEnable = true;
    hostName = "dsh.bdot.in";
    # public-url: https://dsh.bdot.in/，trusted-host: dsh.bdot.in
    modelBaseUrl = "https://llm.bdot.in/v1";
    modelRouterTokenSecret = "dsh/llm_router_token";
    codingAgents.enable = false; # 首版保持关闭
  };
}
~~~

## SOPS 键名

以下仅列键名，不包含值。用户须在可信机器编辑当前 SOPS 密文；不要把私钥、明文 key、
解密 YAML 或 Age 身份文件发送给 ChatGPT。

| 键名 | 使用条件 | 读取方 |
| --- | --- | --- |
| `dsh/llm_router_token` | `dsh.enable = true` | systemd LoadCredential 注入，不写进 store/环境声明/日志 |
| `dsh/cloudflare_tunnel_token` | Cloudflare 模式且 tunnelEnable=true | systemd LoadCredential，仅给 Tunnel `--token-file` |

模块通过 `LoadCredential` 把 token 挂载到专属临时目录 `%d/` 中，启动脚本直接在内存中读取后传给进程环境，既不进入全局环境声明，也不在 Nix store 或运行时日志中留下明文。

用户在可信机器执行 `cd servers && sops secrets/hopper.yaml`，添加上述两个加密
字段，保留现有键和 MAC。本 PR 不修改、创建或覆盖任何 `servers/secrets/*.yaml`。

## 数据目录与备份

| 路径 | 内容 | 策略 |
| --- | --- | --- |
| `/var/lib/dsh/home` | profile、设置、会话与可能的凭据 | 纳入一致性归档，视为敏感数据 |
| `/var/lib/dsh/workspaces` | 明确授权的工作区 | 纳入归档，禁止链接其他服务目录 |
| `/var/cache/dsh` | 可重建缓存 | 不备份 |
| `/var/log/dsh` | 可能含启动凭据的日志 | 不进入通用备份 |
| `/var/lib/restic/staging/dsh/dsh.tar` | 停写后生成的一致性归档 | 加入 hopper-local，再由现有任务镜像 R2 |

模块只向现有 `hopper-local` 追加独立 staging 路径，不再对 `backupPrepareCommand` /
`backupCleanupCommand` 赋第二个定义，不替换数据库导出逻辑，也不新增 R2 凭据。
`dsh-backup-prepare.service` 通过 `Requires` + `After` 在 Restic 前暂停 DSH 与编码 agent
写入者并生成归档。Restic 成功或失败均触发独立 `dsh-backup-resume.service`。DSH、
Codex watcher、任务模板与 self-test 单元通过 NixOS `[Unit]` 中的
`ConditionPathExists=!/run/dsh-backup-session/dsh-paused` 或
`ConditionPathExists=!/run/dsh-backup-session/agents-paused` gate 阻止备份窗口内的新启动。
prepare/resume 共用 root 私有 `flock(LOCK_EX)` 事务锁；helper 原子创建带 session ID 的
gate，恢复时校验 token，只删除本次会话拥有的 gate。恢复逐项检查 DSH start、任务 thaw、
watcher start 与状态验证；任何一步失败都会保留
`/run/dsh-backup-session/state.json` 并以非零状态结束，不执行 runtime mask/unmask，
也不记录或恢复原有 mask 状态。

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


## 本机编码 agent（追加阶段）

本功能由 `dot.hopper.dsh.codingAgents.enable` 控制，默认关闭；当前因适配器 readiness 断言而禁止启用。解除门槛前不得创建或运行 agent 单元。设计上保留原 `dsh` UID 与模型密钥边界，另建无 sudo、wheel、journal、restic 或 SSH 授权的 `dsh-agent` 身份。两者只通过 `/var/lib/dsh/workspaces/coding` 共享工作区；agent 的 home、Codex 登录状态和原始日志位于独立私有目录，不进入备份。

首版只保留 Codex 固定包映射，不包含 WorkBuddy、CodeBuddy 或其他 agent。Codex CLI 参数与 stdin 行为必须对选定 nixpkgs 锁定版本执行 `--help` 核验。runner 采用固定可执行文件映射，不接受请求提供命令、参数、环境变量或 cwd；任务输入有长度限制，结果以固定 JSON 文件原子写入。任务通过固定 path 单元触发，不授权 DSH 调用通用 systemd、sudo 或 transient unit。

**DSH 工具适配器尚未实现**：本轮未确认 PR 当前 DSH 上游版本，亦未确认该版本插件 API。不得伪造插件入口、把文件脚本冒充 OAR app-server 协议，或将功能描述为已接通 DSH。`codingAgents.enable` 有不可绕过的 readiness 断言，在精确依赖锁定、适配器按锁定 API 实现并完成 CLI/ARM64 验收前禁止启用。

任务模板使用独立 systemd UID、只读系统、隐藏 SOPS/SSH/Restic/数据库路径、禁止绑定监听端口和资源/超时限制。出站网络目的地尚未限制，任务仍可能外传其可读代码并产生模型费用；同机 UID 隔离不是 VM 隔离。不得把含凭据的管理员 checkout、home、Git credential 或 SSH agent 接入工作区。

备份路径显式排除 `/var/lib/dsh-agent`，tar 归档同时排除任务队列和认证目录并使用 `--no-xattrs`。备份事务使用同一 flock 串行锁、会话状态文件及 NixOS `ConditionPathExists` gate；prepare 失败/超时由 `OnFailure` 触发恢复，Restic 成功/失败也触发恢复。恢复逐项尝试 DSH、任务 thaw 与 watcher，保留未完成状态供重试；恢复单元失败会向 systemd journal 写入不含密钥的 critical 告警。该流程仍需在目标主机进行 SIGKILL、超时和依赖失败故障注入验收。登录、ARM64 构建、沙箱负向测试、任务取消/超时和恢复演练均未执行。本 PR 不连接服务器、不登录、不部署。


### 备份期间的 DSH 与编码 agent 协调

备份协调不使用 `systemctl mask`、`unmask` 或 runtime mask，也不读取、记录或恢复单元原有
mask 状态。DSH、Codex path watcher、Codex 模板任务及 self-test 单元在 NixOS 声明的
`[Unit]` 中配置 `ConditionPathExists=!/run/dsh-backup-session/dsh-paused` 或
`ConditionPathExists=!/run/dsh-backup-session/agents-paused`。helper 在 root 私有
`/run/dsh-backup-session` 下原子创建带本次 session ID 的 gate 文件；gate 存在时，
对应单元不会启动。这样不会尝试覆盖 `/etc/systemd/system` 中的声明式单元链接或 drop-in。

prepare 与 resume 使用同一个 root 私有 lock 文件和 `flock(LOCK_EX)` 串行化；旧事务状态
尚未恢复时，新 prepare fail-closed。prepare 记录需要恢复的原始 active 状态，停止 watcher，
冻结此前正在运行的 Codex 任务及 self-test，并对 DSH 执行 stop；包括 activating 和
auto-restart 在内的状态均须等待 ActiveState 进入 inactive/failed，且 MainPID、ControlPID
均为 0，才开始归档。任务队列和认证目录仍从归档中排除。

resume 校验 gate 文件中的 session ID，只删除本次会话拥有的 gate，再分别尝试恢复原本
应运行的 DSH、任务和 watcher；DSH 启动失败不会阻止独立的任务 thaw。DSH 恢复还需等待
systemd exec、主进程及 127.0.0.1:3080 TCP 就绪。原本未运行的单元不会被擅自启动。
恢复状态采用 root 0700 目录和 0600 原子写入文件；只有所有必要恢复步骤成功后才删除
状态文件，失败项保留供重试。`ConditionPathExists` gate 与 flock 的实际 systemd 行为、
跨 UID 启停和冻结/解冻效果仍须在目标 NixOS 主机或等价 VM 验收。


## DSH Remote（远程连接插件）

本模块提供移动端（如 Android `dsh-Go`、Remote Web）通过 DSH Remote 协议连入 Hopper DSH 的可选插件支持。

- **插件来源与版本**：官方 npm 包 `ds-harness-remote@0.6.3`（基准源码：<https://github.com/liguobao/ds-harness-remote>），严格锁定并禁止第三方同名包。
- **开关**：`dot.hopper.dsh.remote.enable`（兼容别名 `services.dsh.remote.enable`），默认 `false`。
- **网络与防火墙**：Host 仅向公用中继服务器（默认 `dsh.r2049.cn`）发起出站加密连接，**不开设任何入站端口**，不修改系统防火墙规则，与现有 Cloudflare Tunnel 配置互不冲突。
- **凭据与状态隔离**：设备私钥与 GitHub 登录状态保存在 `/var/lib/dsh/home/ds-harness-remote`（`dsh:dsh 0700`），不进入 Nix store，不进入 Git 仓库。
- **登录与配对流程**：
  1. 在 Hopper 上启用 `dot.hopper.dsh.remote.enable = true;`。
  2. DSH 服务启动后加载该插件，可通过日志或交互命令获取 GitHub Device Flow 授权码完成首次登录。
  3. 在手机端 `dsh-Go` 或浏览器打开 `https://dsh.r2049.cn`，登录相同 GitHub 账号，核对设备指纹后即可连接。
- **关闭与回退**：将 `remote.enable = false`，DSH 启动参数将移除 `--patch`，完全恢复原生运行状态。


# CDN WebSocket 源站加固运维手册

本手册是待执行步骤，不代表已经部署或验证。仅记录不含敏感值的检查结论；真实主机地址、身份、路径和凭据保留在受控环境，不写入仓库、命令历史或日志。**一次只操作一台服务器；每次均先 `nixos-rebuild test`、验收，再 `nixos-rebuild switch`。**

## 1. 前置只读检查

1. 在 Conduit、Hopper 上分别保留当前 SSH 会话并只读查看连接、监听地址。观察 `20001` 是否存在来自外部的已建立连接，记录“存在/不存在”和业务用途，不复制真实对端 IP：

   ```bash
   sudo ss -tnp '( sport = :20001 or dport = :20001 )'
   sudo ss -ltnp '( sport = :20001 )'
   ```

   若仍有依赖公网 `20001` 的客户端、Worker 或其他回源链路，先停止收口计划并确认迁移方案；不能直接把 WS 监听地址设为回环。

2. 只读查看 Cloudflare 对目标 CDN 主机名的 DNS 代理状态、SSL/TLS 模式和所有生效的 Origin Rules，**确认是否有 Origin Rule 将回源直接指向 `20001`**。核对源站端口、Worker/Route 关系与实际业务链路；若仍直连 `20001`，须先规划通过 Nginx `443` 回源并做端到端验收。记录原配置以便在 Cloudflare 恢复，不记录令牌。
3. 在两台服务器分别确认**当前部署所依据的 Git 提交**、工作副本状态和当前系统 generation；不要把工作目录 HEAD 误当作已激活系统：

   ```bash
   git rev-parse HEAD
   git status --short
   nixos-version --configuration-revision
   readlink -f /run/current-system
   ```

   若当前系统无法提供配置修订号，应从部署记录和对应 generation 交叉确认，不猜测。保存脱敏的当前可用性基线：Cloudflare TLS、WS 握手、旧订阅、REALITY、监控与 SSH。

## 2. 合并顺序

依次审阅并合并 **#4 → #5 → #6 → #7 → #8（本 PR）**。每一步核对 GitHub 显示的 base/head、完整 diff、依赖关系和本次提交范围；上游合并后重新核对下游 PR 的目标分支与可合并状态，避免把堆叠分支误合并到错误基线。

合并代码本身不等于部署。每合并一层，都先检查对应声明和公开/私有 Flake 锁的兼容性，再在一台服务器上验证旧业务不变，完成 `test`、检查后才 `switch`；确认稳定后再处理另一台。出现异常立即恢复该主机上一代 NixOS generation，不继续下一层或下一台。两台服务器均未完成验收之前不切换路由器默认流量。

## 3. Cloudflare 与主机分阶段收口

1. **先 Full (strict)**：在目标 CDN 主机名适用的 Cloudflare SSL/TLS 配置作用域设为 `Full (strict)`；如果规则只支持较大作用域，先核对是否影响其他站点。验证 Cloudflare 到源站的证书有效且主机名匹配、TLS 握手和原有 WS 业务均正常。失败则在 Cloudflare 恢复原 SSL/TLS 设置，停止推进。
2. **后 Authenticated Origin Pulls（AOP）**：启用与该 CDN 主机名及证书配置匹配的 Authenticated Origin Pulls，确认 Cloudflare 能提供预期的客户端证书，并验证当前流量保持正常。此时仅启用 Cloudflare 侧 AOP **不等于**源站已经强制校验证书；必须在下一阶段由 Nginx 配置落实。失败则在 Cloudflare 恢复原 AOP 设置。
3. **确认真实回源到 Nginx 443**：若 Origin Rule 仍直连 `20001`，先在 Cloudflare 撤销该直连规则或将回源端口调整到 Nginx `443`，逐台核对真实 WS 握手、长连接与旧订阅。未确认所有活跃客户端与 Worker 已不再使用公网 `20001` 之前，**严禁**收紧 Xray 监听地址。失败则在 Cloudflare 恢复原 Origin Rule；此时保持原主机监听状态。
4. **最后启用主机选项**：准备受信任且公开的 Cloudflare AOP 客户端 CA 证书文件，仅引用其路径，不在此仓库嵌入证书内容或私钥。在私有主机配置中设置 `dot.services.xrayCdnWebSocket.clientCertificateFile`，并设置 `dot.services.xrayNode.webSocketListenAddress = "127.0.0.1"`。先核查生效主机确实使用该 CDN 模块，且 `webSocketPort` 与 Nginx `proxyPass` 一致；这些配置**不得**在本 PR 修改 `hosts/*`。`clientCertificateFile = null` 时 Nginx 的配置应保持原样。
5. **逐台部署**：固定已审阅的公开/私有 Flake 提交，先 Conduit（或明确选定的首台），再 Hopper；每次保留独立 SSH 会话，执行以下模板命令（用受控环境中的真实私有 Flake 和主机名替换占位符）：

   ```bash
   sudo nixos-rebuild test --flake '<PRIVATE_FLAKE>#<HOST>'
   # 验证合格后才执行：
   sudo nixos-rebuild switch --flake '<PRIVATE_FLAKE>#<HOST>'
   ```

   `test` 后核对 Nginx 配置语法与服务状态、CF TLS/AOP 握手、WS 长连接、订阅访问和旧 REALITY 流量；同时用 `ss -tnp` 和 `ss -ltnp` 核对 `20001` 不再承接外部连接且仅按预期监听回环。`switch` 后重复检查，并确保管理 SSH 始终可用。失败立即回滚**当前这一台**，不开始另一台。

## 4. 每一步验证与回滚

| 步骤 | 验证通过条件 | 失败回滚 |
| --- | --- | --- |
| 前置只读盘点 | 两台提交/generation 可追溯，`20001` 外部连接和 Origin Rule 依赖已确认 | 无配置变更；保持原 NixOS generation 和 Cloudflare 设置 |
| #4、#5、#6、#7、#8 逐层合并及单机发布 | 每个 PR 的 base、diff、依赖正确；每台均先 `test` 后 `switch`，旧业务正常 | 已发布的主机恢复上一代 NixOS generation；未发布的主机保持原状 |
| Full (strict) | Cloudflare 到源站证书校验与 WS/TLS 正常 | 在 Cloudflare 恢复原 SSL/TLS 设置 |
| AOP | Cloudflare 正常提供客户端证书，原有请求未中断 | 在 Cloudflare 恢复原 AOP 设置 |
| Origin Rule 改走 443 | 无剩余活跃直连 `20001` 依赖，CDN 流量经 Nginx 可用 | 在 Cloudflare 恢复原 Origin Rule/端口设置 |
| 主机证书校验及回环监听 | `test` 与 `switch` 后源站仅接受受信任 AOP 证书、回环 WS 与业务正常、SSH 可用 | 当前主机恢复上一代 NixOS generation；待监听恢复后，必要时在 Cloudflare 恢复原 AOP/Origin Rule 设置 |

主机回滚示例（仅在已确认的目标机器上执行）：

```bash
sudo nixos-rebuild switch --rollback
```

如收口后必须恢复 Cloudflare 直连 `20001`，**先**恢复对应主机上一代 generation 并验证端口恢复，**再**在 Cloudflare 恢复原 Origin Rule；反序操作会造成回源中断。Cloudflare 设置回滚均按第一步保存的原配置逐项恢复，并复测实际 WS 与 TLS，不把 DNS/Worker 状态凭空视为已恢复。

## 5. 旧模板 Worker 下线后的核对项

- 核对旧 Worker 的 routes、custom domains、DNS、订阅/provider 引用及定时任务均不再指向已下线模板，新的交付与回源链路已完成实机验收。
- 检查路由器实际活动策略组、订阅刷新、备用出口、WS/REALITY 连接和两台回源健康；不以配置存在或 Worker 已部署替代实际流量验证。
- 核对旧 Worker 的 KV/R2 绑定、配置交付依赖、优选更新任务和日志保留策略；按审批流程清理失效资源，不导出含敏感请求参数的旧日志。
- 核对已停用旧模板的 Worker secret、API Token、路由器上传权限与 GitHub 访问权限是否已撤销；保留必要的脱敏审计与回滚记录。
- 下线动作仅在新链路稳定且回退方案确认后执行；异常时优先在 Cloudflare 恢复原路由/Worker 设置，必要时恢复上一代 NixOS generation。

## 6. 应轮换的凭据类别（不记录具体值）

- 旧模板 Worker 与 Cloudflare 管理 API Token、部署令牌。
- Worker secret、KV/R2 访问密钥及其他云端服务凭据。
- 路由器优选结果上传签名密钥、GitHub PAT 和自动化访问令牌。
- VLESS 客户端 UUID、Trojan 密码、WebSocket 路径及订阅访问令牌。
- 独立路由器生产账号凭据、配置交付令牌及回源证明/探测身份。
- REALITY 私钥与相关客户端认证材料、源站 TLS 私钥（按暴露风险决定轮换范围）。

轮换须遵循先建立新凭据、双端验证、再撤销旧凭据的顺序；不提交任何真实凭据或运行时解密材料。

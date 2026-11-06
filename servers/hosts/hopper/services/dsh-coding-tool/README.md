# DSH 本机 Codex 工具适配器（未实现）

首版只计划支持 Codex。当前目录不包含插件适配器实现；不得把任务文件交换脚本冒充 DSH 插件或 OAR app-server stdio provider。

`dot.hopper.dsh.codingAgents.enable` 带有不可绕过的 readiness 断言，当前始终禁止启用。解除门槛前必须先锁定精确 DSH 发布版本、生成并审查 `package-lock.json` 与真实 `npmDepsHash`，再按该不可变版本的插件 API 实现固定的提交、状态查询和取消工具，并完成 ARM64 构建、CLI/认证及沙箱验收。

runner 的队列路径边界回归测试可在仓库检出后运行：

```sh
python3 servers/hosts/hopper/services/dsh-agent-runner-tests.py
```

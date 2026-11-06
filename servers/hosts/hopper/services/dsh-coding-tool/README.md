# DSH 本机编码工具适配器（待上游版本确认）

此目录有意不提供伪造的插件实现。

当前 PR 的 DSH 包版本仍为用户决策占位，未生成 npm lockfile；因此无法可靠确定插件注册 API、工具 schema、调用生命周期或超时/取消约定。不得根据移动分支猜测接口，也不得把一次性 JSON 文件脚本冒充 OAR app-server stdio provider。

后续实现必须只提供固定工具：提交 `tool/prompt/jobId` 到受控任务队列并读取对应结果；不得接收 shell 命令、systemd 参数、任意 cwd、环境变量或 CLI flags。在精确 DSH 版本锁定并按该版本源码/类型定义实现前，适配器和 `dot.hopper.dsh.codingAgents.enable` 均保持不可用。

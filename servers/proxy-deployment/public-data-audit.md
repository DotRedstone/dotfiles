# 公开代理部署数据审计

状态：2026-10-18，针对当前代理 PR 的 HEAD 与 `origin/main` 差异。本文只记录
类别和路径；历史提交及远端缓存仍需另行处置。

## 当前 HEAD 的收敛

- Worker 名称、独立 KV 标识、交付域名与来源清单从
  `cloudflare-resources.json`、`preferred-sources.json` 移入
  `servers/secrets/cloudflare.yaml` 的 SOPS 密文。准备脚本正式运行时解密读取；
  `--dry-run` 使用 `*.example.json` 的合成值。
- 发布账户与来源映射、控制 Worker 读取入口移入
  `servers/secrets/conduit.yaml` 的 `proxy/delivery_runtime`。Conduit 构建只复制
  节点、域名目录和 profile 结构；运行时以 root-only SOPS 文件装配账户与来源。
  发布器仍读取旧版池和 manifest，现用 Worker、KV、订阅均未切换。
- 交接文档以 `example.test`、`SOURCE_ID` 等明显占位符替代此次 PR 新增的
  部署域名、资源 ID、版本标识及来源标识。示例无真实账户或端点。

## 尚需迁移的公开部署值

- `origin/main` 早已包含节点地址和自有域名；本 PR 的 `nodes.json` 与
  `owned-domains.json` 仍引用这些既有公开值。它们不是凭据，移除当前 HEAD
  不能撤回旧历史中的披露。
- 目标主机默认关闭的 `probe-tls.nix` 已将探测域名默认值清空，并在启用时
  要求提供受限输入；`scripts/check-probe-inputs.mjs` 从 Cloudflare SOPS 读取
  探测名称和 origin 身份映射，实测检查仍通过。
- 两地主机的 `cross-probe.nix` 仍包含当前探测证书名称。这些值参与 Nix
  求值、Nginx 与证书配置；[私有 overlay 合成原型](../private-overlay.example/README.md)
  已证明三个主机可以纯求值追加覆盖模块。只有私有 overlay 已固定实际输入、
  完成构建及运行验收后，才可删除公开主机模块中的当前字面量。
- 两地主机的 `canary-origin.nix` 与相关交接记录仍使用当前部署的 origin
  身份标签。这是路由/证明身份元数据，不是凭据；后续应随受信任 origin
  目录一起迁移，保持现有身份继续可读。私有 overlay 原型可覆盖这两项，
  但当前未迁移现用主机。
- 现有脚本与部署参数仍围绕两地当前 origin ID。通用契约后续应接受受信任
  节点目录提供的 ID 集合，保持现有两地键和旧 v1 数据可读；此项由各独立
  项目另行验证，不在当前隐私修补中修改或部署。

## 历史与回退

PR 已推送的旧提交含上述部署标识。HEAD 脱敏只减少后续复制，不删除已公开的
Git 对象、PR diff 或外部缓存。没有在本次扫描中发现非 SOPS 文件内的明文
API token、私钥或密码；Worker 版本号和 KV 标识按部署元数据处理。

历史清理需要另行约定窗口：先在受限输入中完成部署和回退验收，保留旧闭包、
旧 Worker/订阅；再从 `origin/main` 建立已脱敏的替代分支，逐项核对差异，
协调 PR/分支历史改写与远端缓存处理。若后续发现有效凭据明文，应先撤销或
轮换，再讨论历史清理。当前不强推、不重写 main，也不改变运行中服务。

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
- 2026-10-18 对公开跟踪文件按 SOPS 中的 Worker 资源、来源 ID、探测证书名称
  和 origin 身份作精确匹配，当前工作树四类均为零命中。该检查不覆盖旧 main
  中其他已公开值，也不能撤回远端历史。

## 尚需迁移的公开部署值

- `origin/main` 早已包含节点地址和自有域名；本 PR 的 `nodes.json` 与
  `owned-domains.json` 仍引用这些既有公开值。它们不是凭据，移除当前 HEAD
  不能撤回旧历史中的披露。
- Target 原有的 `probe-tls.nix` 已移除，不再提供该 TLS 探测模块；
  `scripts/check-probe-inputs.mjs` 从 Cloudflare SOPS 读取
  探测名称和 origin 身份映射，实测检查仍通过。
- 两地主机的 `cross-probe.nix` 已去除当前探测证书名称。这些值参与 Nix
  求值、Nginx 与证书配置；[私有 overlay 合成原型](../private-overlay.example/README.md)
  已证明三个主机可以纯求值追加覆盖模块。两地主机当前部署值已保存在本机
  独立私有 overlay（无远端，已固定公开 Flake 修订）；公开 Flake 只提供构造器，
  不再输出两地主机的直接部署目标。Conduit 已用该输入完成临时 `test` 并回退，
  Hopper 候选与当前运行闭包相同；两地主机均未因该 overlay 执行持久切换。
- 两地主机的 `canary-origin.nix` 已去除部署 origin 身份字面量；相关交接
  文档使用占位符。实际值仅在本机私有 overlay 与 SOPS 受限映射中，
  现用服务未持久部署到该候选。旧 PR 历史中的原字面量仍可访问。
- 现有脚本与部署参数仍围绕两地当前 origin ID。通用契约后续应接受受信任
  节点目录提供的 ID 集合，保持现有两地键和旧 v1 数据可读；此项由各独立
  项目另行验证，不在当前隐私修补中修改或部署。

## 历史与回退

PR 已推送的旧提交含上述部署标识。HEAD 脱敏只减少后续复制，不删除已公开的
Git 对象、PR diff 或外部缓存。没有在本次扫描中发现非 SOPS 文件内的明文
API token、私钥或密码；Worker 版本号和 KV 标识按部署元数据处理。

历史改写不是单次可回退主机切换的技术前置条件，但私有 overlay 当前锁定 PR
中的固定提交。若历史改写使该提交失去可获取的引用，须先重新锁定稳定的审查
修订并复核候选闭包。公开合并前应另行处置旧 PR 历史中的部署标识；既有 main
披露不能仅靠重写 PR 分支撤回。

历史清理需要另行约定窗口：先在受限输入中完成部署和回退验收，保留旧闭包、
旧 Worker/订阅；再从 `origin/main` 建立已脱敏的替代分支，逐项核对差异，
协调 PR/分支历史改写与远端缓存处理。若后续发现有效凭据明文，应先撤销或
轮换，再讨论历史清理。当前不强推、不重写 main，也不改变运行中服务。

# 私有服务器部署 overlay 示例

本目录仅含 `example.test` 和合成 origin ID，不包含当前部署值。NixOS 的证书名称、
回源身份和虚拟主机名称在求值期进入系统闭包，运行期 SOPS 文件不能替代这些
Nix 选项。独立私有 Flake 可用 `extendModules` 在公开服务器 Flake 上追加少量
主机专属值，通用服务实现仍由公开仓库维护。

## 评审与迁移顺序

1. 将本目录复制到不公开的独立 Git 仓库；只在该仓库填写两地主机的 origin
   身份和探测证书名称。固定已审查的公开服务器 Flake 修订并保存私有 lock。
   不在公开仓库或 PR 中提交真实 overlay、构建日志或解密文件。
2. 先用合成值验证接口；再在私有仓库比较 overlay 的有效 `originId`、
   `serverName`、Target TLS `domain` 与当前系统声明值是否一致。分别评估
   Conduit、Hopper、Target 的系统闭包，并核对 Nginx、ACME、探测及旧回源。
3. 在有定时回退保护的维护窗口逐机执行 `nixos-rebuild test`，实测 TLS、
   回源证明、SSH 和旧订阅；验收后再 `switch`。保留旧闭包和受限输入。
4. 只有私有 overlay 已成为实际构建入口并完成回退验证后，才在单独提交中
   删除公开主机模块中的当前部署字面量。历史清理仍需另行协调。

合成原型可在 dotfiles worktree 中执行以下只求值检查；它不部署主机：

```bash
cd /path/to/dotfiles-worktree
nix flake check --no-build --no-write-lock-file \
  --override-input public "path:$PWD/servers" \
  path:./servers/private-overlay.example
```

本示例保持 Target TLS 探测关闭。私有 overlay 只提供未来启用时的名称，不启用
服务或修改当前 DNS/证书。
